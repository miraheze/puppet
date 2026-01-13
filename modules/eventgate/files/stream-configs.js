'use strict';

/**
 * Functions to retrieve stream config from either a static or dynamic URL.
 */

const _ = require('lodash');

const {
    urlGetObject,
} = require('@wikimedia/url-get');

/**
 * Retries calling the provided async fn up to retryLimit times.
 *
 * @param {Function} fn
 * @param {int} retryLimit
 * @param {string} customRetryWarnMessage
 *      If set, this message will be used in the warning log message on errors
 *      caught before retry limit is reached.
 * @param {Object} logger
 * @return {Promise} result of fn
 */
async function retryFn(fn, retryLimit, customRetryWarnMessage, logger) {
    for (let tryNum = 1; tryNum <= retryLimit; tryNum++) {
        try {
            return await fn();
        } catch (error) {
            if (logger) {
                const warnMessage =  customRetryWarnMessage ||
                    'Caught error when calling function';
                logger.warn(
                    warnMessage + ` on try number ${tryNum} out of ${retryLimit}`,
                    { error }
                );
            }
            if (tryNum === retryLimit) {
                throw error;
            }
        }
    }
}

/**
 * Compiles any stream name regex keys in streamConfigsData to stream_regex RegExps settings.
 *
 * @param {Object} streamConfigsData
 *      Object containing stream name => stream settings.
 *      Stream name might be regex patterns.
 * @return {Object}
 *      The same streamConfigs object, but with keys that look like regexes compiled
 *      to RegExps set as a new 'stream_regex' setting.
 */
function compileStreamConfigRegexes(streamConfigsData) {
    return _.reduce(streamConfigsData, (result, streamConfig, key) => {
        result[key] = streamConfig;
        // If this stream key looks like a regex, create a new RegExp.
        if (key.startsWith('/') && key.endsWith('/') && _.isUndefined(streamConfig.stream_regex)) {
            // eslint-disable-next-line security/detect-non-literal-regexp
            result[key].stream_regex = new RegExp(key.slice(1, key.length - 1));
        }
        return result;
    }, {});
}

/**
 * A StreamConfigs instance looks up stream configs from a configured URI,
 * and provides functions to get config for a specific stream.
 * This is its own class, rather than a simple object, so we can
 * wrap re-fetching the stream configs after a TTL, as well as handle
 * getting configs for a stream by regex pattern.
 *
 * Usage:
 *  const streamConfigs = new StreamConfigs({
 *      stream_config_uri: "...",
 *      stream_config_ttl: 60,
 *      // ...
 *  });
 *  await streamConfigs.init(); // have to call init to populate initial configs.
 *  const specificStreamConfig = streamConfigs.get("my.stream.name");
 */
class StreamConfigs {
    /**
     * @param {Object} options
     * @param {string} options.stream_config_uri
     * @param {string} options.stream_config_uri_options
     * @param {string} options.stream_config_object_path
     * @param {string} options.stream_config_ttl
     * @param {string} options.stream_config_retries
     * @param {Object} logger
     *      an instantiated winston logger instance.
     */
    constructor(options, logger) {
        this.log = logger;

        this.stream_config_uri = options.stream_config_uri;
        this.stream_config_uri_options = options.stream_config_uri_options;
        this.stream_config_object_path = options.stream_config_object_path;
        this.stream_config_ttl = options.stream_config_ttl;
        this.stream_config_retries = options.stream_config_retries;

        this._streamConfigs = null;
        this._regexMatchedStreamConfigs = null;
    }

    /**
     * Fetches initial stream configs from stream_config_uri.
     * If stream_config_ttl was configured, an interval timer will be set
     * up to periodically refetch from stream_config_uri.
     *
     * NOTE: if a refetch attempt fails, the previously fetched stream configs
     * will continue to be used.  This will avoid having a temporarily unavailable
     * remote stream config endpoint causing the application to fail.
     */
    async init() {
        if (this._streamConfigs !== null) {
            throw new Error('Cannot call init() on an already initialized StreamConfigs object.');
        }

        this._streamConfigs = await this._fetchStreamConfigs();
        this._regexMatchedStreamConfigs = {};

        if (this.stream_config_ttl && this.stream_config_ttl > 0) {
            const timeout = setInterval(async () => {
                this.log.info(`Refetching stream configs from ${this.stream_config_uri}.`);
                let refetchedStreamConfigs;
                try {
                    refetchedStreamConfigs = await this._fetchStreamConfigs();
                } catch (err) {
                    this.log.error(
                        `Failed refetching stream configs from ${this.stream_config_uri}. ` +
                        'Keeping previously fetched stream configs.'
                    );
                }

                if (refetchedStreamConfigs) {
                    this._streamConfigs = refetchedStreamConfigs;
                    this._regexMatchedStreamConfigs = {};
                }
            }, this.stream_config_ttl * 1000.0);
            timeout.unref();
        }
    }

    /**
     * Returns a list of all currently known stream config keys.
     *
     * @return {Array}
     */
    keys() {
        if (this._streamConfigs === null) {
            throw new Error('Must call init() before accessing stream configs');
        }

        return _.keys(this._streamConfigs);
    }

    /**
     * Gets the settings for the given stream.
     *
     * @param {string} stream
     * @return {Object}
     */
    get(stream) {
        if (this._streamConfigs === null) {
            throw new Error('Must call init() before accessing stream configs');
        }

        return this._getConfigsForStreams([stream])[stream];
    }

    /**
     * Gets settings for multiple streams.
     * The returned Object will be keyed by stream name.
     *
     * @param {Array} streams
     * @return {Object}
     */
    mget(streams) {
        if (this._streamConfigs === null) {
            throw new Error('Must call init() before accessing stream configs');
        }

        return this._getConfigsForStreams(streams);
    }

    /**
     * Collects the matching stream configs for the requested streams.
     * If any stream config keys are regex patterns, the requested streams
     * will be attemtped to match against these keys at this time.
     *
     * If a stream name happens to match more than one regex, this stream match
     * will be cached and saved until the cache is expired (after stream_config_ttl).
     * It is undefined behavior which stream name pattern will match.
     * You should avoid using regex stream names that can overlap matches.
     * E.g. you should never configure a stream name as a regex pattern that
     * overlaps with another stream name regex pattern's matches.
     *
     * @param {Array} streams
     * @return {Object}
     */
    _getConfigsForStreams(streams) {
        // Since we might have stream_regex settings in streamConfigs, we need
        // to search it for the requested streams that might match those keys.
        // stringMatches works on both regexes and regular strings (with equality).
        // This reduce returns a stream configs object keyed by real stream name
        // to real stream config settings object.
        const matchedStreamConfigs = streams.reduce((result, stream) => {
            let matchedKey;
            if (_.has(this._streamConfigs, stream)) {
                matchedKey = stream;
            } else {
                // else for all streamConfigs that have a compiled stream_regex,
                // look for a regex that matches the stream name we are looking for.
                matchedKey = _.findKey(this._streamConfigs, (streamConfig) => {
                    return _.has(streamConfig, 'stream_regex') && streamConfig.stream_regex.test(stream);
                });
            }

            if (!_.isUndefined(matchedKey)) {
                const specificStreamConfig = _.cloneDeep(this._streamConfigs[matchedKey]);

                // if this stream matched a regex, then
                // save the streamConfig for this stream as a new
                // entry in the cached _streamConfig keyed by the
                // requested stream name (and delete the compiled stream_regex from it).
                // This will avoid having to match this stream agaist a regex the next
                // time it is requested, as it will exist keyed by name in this._streamConfigs.
                if (specificStreamConfig.stream_regex) {
                    delete specificStreamConfig.stream_regex;
                    this._streamConfigs[stream] = specificStreamConfig;
                }
                result[stream] = specificStreamConfig;
            }
            return result;
        }, {});

        // Log if the requested streams configs are missing, undefined, or empty.
        // See also: https://phabricator.wikimedia.org/T263672
        streams.forEach((stream) => {
            if (!_.has(matchedStreamConfigs, stream)) {
                this.log.warn(
                    `Stream ${stream} is not present in stream configs ` +
                    `loaded from ${this.stream_config_uri}`,
                    { stream_configs: this._streamConfigs }
                );
            } else if (_.isUndefined(matchedStreamConfigs[stream])) {
                this.log.warn(
                    `Stream ${stream} is undefined in stream configs ` +
                    `loaded from ${this.stream_config_uri}`,
                    { stream_configs: this._streamConfigs }
                );
            } else if (_.isEmpty(matchedStreamConfigs[stream])) {
                this.log.warn(
                    `Stream ${stream} is present in stream configs but has no settings ` +
                    `loaded from ${this.stream_config_uri}`,
                    { stream_configs: this._streamConfigs }
                );
            }
        });

        return matchedStreamConfigs;
    }

    /**
     * Fetches stream configs from the configured stream_config_uri,
     * with configured stream_config_retries.
     *
     * @return {Object}
     */
    async _fetchStreamConfigs() {
        const fetchStreamConfigs = async () => {
            this.log.info(`Fetching stream configs from ${this.stream_config_uri}`);
            const streamConfigsResult = await urlGetObject(
                this.stream_config_uri,
                this.stream_config_uri_options || {}
            );

            // If action=streamconfigs is in the URI, assume this is the
            // MediaWiki EventStreamConfig Action API. The Action API almost
            // always returns HTTP 200, so we can't rely on urlGetObject to
            // throw an Error on some failures.  We need to inspect the response body.
            if (this.stream_config_uri.includes('action=streamconfigs')) {
                if (_.has(streamConfigsResult, 'warnings')) {
                    this.log.warn(
                        'Got warnings in response body when requesting ' +
                        `stream config from ${this.stream_config_uri}`,
                        { response_body: streamConfigsResult }
                    );
                }
                if (_.has(streamConfigsResult, 'error')) {
                    const errorMessage =
                        'Got error in response body when requesting ' +
                        `stream config from ${this.stream_config_uri}`;
                    this.log.error(errorMessage, { body: streamConfigsResult });
                    throw new Error(errorMessage);
                }
            }

            // If stream_config_object_path was configured,
            // expect the config settings for streams to exist at that path.
            return this.stream_config_object_path ?
                _.get(streamConfigsResult, this.stream_config_object_path) :
                streamConfigsResult;
        };

        // Wrap fetchStreamConfigs with retries.
        const fetchedStreamConfigs = await retryFn(
            () => fetchStreamConfigs(this.stream_config_uri),
            this.stream_config_retries || 1,
            `Failed fetching stream configs from ${this.stream_config_uri}`,
            this.log
        );

        // Pre-compile any regex stream name keys to RegExp.
        return compileStreamConfigRegexes(fetchedStreamConfigs);
    }
}

/**
 * Returns an initalized StreamConfigs instance.
 *
 * @param {Object} options
 * @param {Object} logger
 * @return {StreamConfigs}
 */
async function makeStreamConfigs(options, logger) {
    const streamConfigs = new StreamConfigs(options, logger);
    await streamConfigs.init();
    return streamConfigs;
}

module.exports = {
    makeStreamConfigs
};
