#!/usr/bin/env node
'use strict';

const _ = require('lodash');
const { v1: uuidv1 } = require('uuid');

const {
    urlGetObject,
    uriHasProtocol,
    uriGetFirstObject,
} = require('@wikimedia/url-get');

const EventValidator = require('./src/lib/EventValidator.js');
const EventGate = require('./src/lib/eventgate.js').EventGate;
const util = require('./src/lib/event-util.js');
const error = require('./src/lib/error.js');

const {
    objectGet,
    makeExtractField,
} = util;

const {
    MissingFieldError,
    ValidationError
} = error;

// Used for getting static or dynamic remote stream configs.
const {
    makeStreamConfigs,
} = require('./stream-configs.js');

/**
 * This module can be used as the value of app.options.eventgate_factory_module.  It exports
 * a factory function that given options and a logger, returns an instantiated EventGate instance
 * that will produce to Kafka, and a mapToEventError function for transforming
 * errors into events that can be produced to an error topic.
 *
 * This file contains various functions for configuring and creating the main 'custom'
 * EventGate instance using Express app.options.  These functions all use a options object
 * to make new functions that extract information from events (e.g. schema_uri_field)
 * and to create validate and produce functions for constructing the EventGate instance.
 *
 * makeExtractSchemaUri exported by default-eventgate module is used, but
 * this file mostly creates and uses new specific functions.
 *
 * The following keys are used in the options argument in functions here.
 *
 * - schema_uri_field
 *      The dotted object path to extract a schema_uri from an event.
 *      Default: $schema
 *
 * - schema_base_uris
 *      Base URIs in which to search for URIs extracted from event schema_uri_fields
 *      Default: undefined
 *
 * - schema_file_extension
 *      A file extension to append to the extracted schema_uri_field if its
 *      URI doesn't already have one.
 *      Default: undefined
 *
 * - stream_field
 *      The dotted object path to the value to use for the topic/stream.
 *      If this is not given, the stream_uri_field will be used to construct
 *      a sanitized stream name.
 *      Default: undefined
 *
 * - stream_config_uri
 *     A URI from which 'stream configuration' will be fetched.  The result
 *     should be either be a static stream name (or regex pattern) to stream config map.
 *     The objects returned by this URI should map a stream name to its config,
 *     which must include schema_title.  schema_title must match exactly
 *     incoming event schema's title field, or it will be rejected.
 *
 *     If stream_config_uri is undefined, then any event will be allowed in
 *     any stream, as long as it validates with its schema.
 *
 * - stream_config_uri_options
 *     If provided, these options will be passed when opening stream_config_uri
 *     for reading.  If this is a local file path, fs.readFile options should be
 *     given.  If this is a remote http URI, preq.get options should be used.
 *
 * - stream_config_object_path
 *      If set, the stream configs are expected to live in a subobject
 *      of the result object returned from stream_config_uri. The stream
 *      configs object will be extracted at this path.
 *      This should be a path string that Lodash#get understands.
 *
 * - stream_config_ttl
 *      If set, stream configs will be periodically refetched at this interval.
 *      Default: 0 (no TTL).
 *
 * - stream_config_retries:
 *      Retry up to this many tines when fetching stream config from stream_config_uri.
 *      Default: 1
 *
 * - topic_prefix
 *      If given, this will be prefixed to the value extracted from stream_field
 *      and used for the Kafka topic the event will be produced to.
 *      Default: undefined
 *
 * - id_field
 *      This field will be used as the event's 'id' in log messages
 *      Default: meta.id
 *
 * - dt_field
 *      This field will extracted and used for the Kafka message timestamp.
 *      This field value should be in ISO-8601 format.
 *      Default: meta.dt
 *
 * - kafka.conf
 *      node-rdkafka KafkaProducer configuration
 *
 * - kafka.topic_conf
 *      node-rdkafka KafkaProducer topic configuration
 *
 * - kafka.{guaranteed,hasty}.conf
 *      Producer type specific overides. Use this to set e.g. batching settings
 *      different for each producer type.
 */

const defaultOptions = {
    schema_uri_field: '$schema',
    schema_base_uris: undefined,
    schema_file_extension: undefined,
    stream_field: 'meta.stream',
    dt_field: 'meta.dt',
    id_field: 'meta.id',
    topic_prefix: undefined,
    kafka: {
        conf: {
            'metadata.broker.list': 'localhost:9092'
        },
        topic_conf: {}
    },
    http_request_headers_to_fields: {
        'x-request-id': 'meta.request_id',
        'user-agent': 'http.request_headers.user-agent',
    },
};

/**
 * The schema URI of the error event that will be created and produced
 * for event validation errors.  Change this when you change
 * error schema versions.
 */
const errorSchemaUri = '/error/1.0.0';

/**
 * Utility function to DRY up requiring optionalDependencies with a
 * helpful Error if the module is not installed.
 *
 * @param {string} moduleName
 * @return {Object}
 */
 function requireOptional(moduleName) {
    let m;
    try {
        // eslint-disable-next-line security/detect-non-literal-require
        m = require(moduleName);
    } catch (e) {
        if (e.code === 'MODULE_NOT_FOUND') {
            throw new Error(
                `${moduleName} is an optionalDependency and needs to be ` +
                'installed. Run npm install (without the --no-optional flag).'
            );
        } else {
            throw e;
        }
    }
    return m;
}

/**
 * Returns a new mapToErrorEvent function that uses options.error_schema_uri
 * and options.error_stream to return an error event that conforms to the
 * error event schema used by us.  This function only returns
 * error events for ValidationErrors.
 *
 * @param {Object} options
 * @param {Object} metrics service-runner metrics interface.  This is provided from
 *      service-runner app.
 * @return {function(Object, Object, Object): Object}
 */
function makeMapToErrorEvent(options, metrics) {

    let validationErrorMetric;
    if (metrics) {
        validationErrorMetric = metrics.makeMetric({
            type: 'Counter',
            name: 'events.errors.validation',
            prometheus: {
                name: 'eventgate_validation_errors_total',
                help: 'EventGate events with schema validation errors',
                staticLabels: metrics.getServiceLabel(),
            },
            labels: {
                names: ['stream', 'schema_uri'],
            },
        });
    }

    return (error, event, context = {}) => {
        // Only produce error events for ValidationErrors.
        if (!(error instanceof ValidationError)) {
            // Returning null will cause this particular error event
            // to not be produced at all.
            return null;
        }

        const now = new Date();

        /**
         * Like lodash _.get().toString(), except if the value is defined and it is null,
         * returns 'null'. Most values have a toString method, but null does
         * not.
         *
         * @param {Object} object
         * @param {string} path
         * @param {*} defaultValue
         * @return {string}
         */
        function getToString(object, path, defaultValue) {
            const v = _.get(object, path, defaultValue);
            if (_.isNull(v)) {
                return 'null';
            } else {
                return v.toString();
            }
        }

        const errorEvent = {
            meta: {
                id: uuidv1(),
                dt: now.toISOString(),
                uri: getToString(event, 'meta.uri', 'unknown'),
                domain: getToString(event, 'meta.domain', 'unknown'),
                request_id: getToString(event, 'meta.request_id', 'unknown')
            },
            emitter_id: options.user_agent || 'eventgate-service',
            raw_event: _.isString(event) ? event : JSON.stringify(event),
            // We know error is an ValidationError,
            // so we can use errorsText as error message.
            message: error.errorsText
        };

        // Get the preferred schema_uri_field and stream_field
        // and set them on the event.
        /* eslint-disable */
        const schemaUriField =_.isArray(options.schema_uri_field) ?
            options.schema_uri_field[0] :
            options.schema_uri_field;
       const streamField = _.isArray(options.stream_field) ?
            options.stream_field[0] :
            options.stream_field;
        /* eslint-enable */

        _.set(errorEvent, schemaUriField, errorSchemaUri);
        _.set(errorEvent, streamField, options.error_stream);

        // if event an object, we should be able to include
        // top level infomration in our error event about
        // which stream and which schema this validation
        // error is about.
        if (_.isObject(event)) {
            _.set(
                errorEvent,
                'errored_schema_uri',
                _.get(event, schemaUriField, 'unknown')
            );
            _.set(
                errorEvent,
                'errored_stream_name',
                _.get(event, streamField, 'unknown')
            );
        }

        if (validationErrorMetric) {
            // Increment the validation errors seen for this stream.
            validationErrorMetric.increment(
                1,
                [errorEvent.errored_stream_name, errorEvent.errored_schema_uri]
            );
        }

        return errorEvent;
    };
}

/**
 * Returns a function that extracts the event's schema URI.
 *
 * @param {Object} options
 * @param {string|Array<string>} options.schema_uri_field
 *      Field(s) used to extract the schema_uri from an event.
 *      If this is an array, the event will be searched for a field
 *      named by each element. The first match will be used.
 *      This allows you to support events that might have
 *      Their schema_uris at different locations.  If this is not set,
 *      defaultOptions.schema_uri_field will be used.
 * @return {function(Object, Object): string}
 */
function makeExtractSchemaUri(options) {
    const schemaUriField = _.get(options, 'schema_uri_field', defaultOptions.schema_uri_field);
    return makeExtractField(schemaUriField);
}

/**
 * All our events should have stream_field set.  The function
 * created by this function returns the value extracted from event at stream_field.
 *
 * @param {Object} options
 * @param {string} options.stream_field
 * @return {function(Object, Object): string}
 */
function makeExtractStream(options) {
    return makeExtractField(options.stream_field);
}

/**
 * Returns a function that extracts options.dt_field from event
 * and then converts it to unix epoch millseconds.
 * If dt_field is not in event, this function will return null.
 *
 * @param {Object} options
 * @param {string} options.dt_field  The value of this field should be in ISO-8601 format.
 * @return {function(Object, Object): string}
 */
function makeExtractTimestamp(options) {
    // Use null as default return value if dt_field is missing in event.
    const extractDt = makeExtractField(options.dt_field, null);
    return (event, context = {}) => {
        const dt = extractDt(event, context);
        if (dt) {
            return new Date(dt).getTime();
        } else {
            return null;
        }
    };
}

/**
 * Creates a function that returns a string representation of an event useful for logging.
 *
 * @param {Object} options
 * @param {string} options.id_field
 *      Used to extract the event's 'id'.
 * @param {string} options.schema_uri_field
 *      Used to extract the event's schema URI.
 * @param {string} options.stream_field
 *      Used to extract the event's destination stream name.
 * @return {function(Object, Object): string}
 */
function makeEventRepr(options) {
    // Use the already constructed functions if they are set in options, else
    // make them from options now.
    const extractSchemaUri = options.extractSchemaUri || makeExtractSchemaUri(options);
    const extractStream    = options.extractStream || makeExtractStream(options);

    /**
     * Returns f(args), unless an MissingFieldError is thrown, in which case defaultValue
     * will be returned.
     * eventRepr() should never throw, and it gets called with possibly-incomplete objects
     * as part of debug logging, so we need to be defensive here.
     *
     * @param {Function} f
     * @param {*} defaultValue
     * @param {Array} args
     * @return {*}
     */
    function extractOrElse(f, defaultValue = null, args = []) {
        try {
            return f.apply(undefined, args);
        } catch (err) {
            if (err instanceof MissingFieldError) {
                return defaultValue;
            } else {
                throw err;
            }
        }
    }

    return (event, context = {}) => {
        const eventId    = _.get(event, options.id_field);
        const schemaUri  = extractOrElse(extractSchemaUri, 'unknown', [ event ]);
        const stream     = extractOrElse(extractStream, 'unknown', [ event ]);

        return 'event' +
            (eventId ? ` ${eventId}` : '') +
            (schemaUri ? ` of schema at ${schemaUri}` : '') +
            (stream ? ` destined to stream ${stream}` : '');
    };
}

/**
 * Given a field name (e.g. `meta.request_id`), translates that field name to a path
 * in the schema (e.g. `properties.meta.properties.request_id`). Field must be non-empty.
 *
 * @param {string} field
 * @return {string}
 */
function fieldNameToSchemaName(field) {
    return 'properties.' + field.split('.').join('.properties.');
}

/**
 * Given a field name (e.g. `meta.request_id`), returns the name of the parent field
 * (e.g. `meta`). Field must be non-empty.
 *
 * @param {string} field
 * @return {string}
 */
function parentOfField(field) {
    return field.split('.').slice(0, -1).join('.');
}

/**
 * Makes a function that will set some custom required fields with
 * values if they are not set by the client.  These event fields
 * will only be set if they are present in the event's schema.
 *
 * This function will default event[schema_uri_field] and event[stream_field] from
 * query parameters. This helps for cases where we don't have control over
 * producer code, but want to produce JSON events of a known schema to specific stream
 * to a predetermined URL.
 * E.g. (url encoded of course):
 *  POST /v2/events?schema_uri=/cool/schema/1.0.0&stream=cool.stream
 *
 * Sets:
 *
 *  - options.schema_uri_field
 *      To value of options.schema_uri_query_param if provided in HTTP request.
 *
 *  - options.stream_field
 *      To value of options.stream_field if provided in HTTP request.
 *
 *  - meta.dt
 *      To current ISO-8601 UTC timestamp
 *
 * - dt
 *      If schema.title starts with 'analytics/legacy', dt defaults to a server
 *      side receive timestamp. In most cases we use the dt field as a client
 *      side AKA event timestamp and don't touch it here. However, EventLogging legacy
 *      schemas (all of which start with 'analytics/legacy') used dt as a server side
 *      timestamp, and we want to maintain compatible semantics for this field for them.
 *
 *  - meta.id
 *      To new uuid
 *
 *  - meta.request_id
 *      To value of X-Request-ID request header if set.
 *
 *  - http.client_ip
 *      To value of X-Client-IP request header if set.
 *
 *  - http.request_headers['user-agent']
 *      To value of User-Agent request header if set.
 *
 * @param {Object} options
 * @param {function(Object): Object} options.getSchemaForEvent
 *     Given an event, returns the event's JSONSchema.  This likely should be
 *     a bound EventValidator schemaFor function, so that
 *     any event schema lookups are always done in the same way, and cached.
 *     This option is required.
 * @param {function(Object, Object): Object} options.eventRepr
 * @param {Object} logger
 * @return {function(Object, Object): Object}
 *      (event, context) => event
 *      context.req must be set to the http ClientRequest
 */
function makeSetCustomDefaults(options, logger) {
    if (!_.isFunction(options.getSchemaForEvent)) {
        throw new Error(
            'Must set options.getSchemaForEvent to a function for makeSetCustomDefaults.'
        );
    }
    const getSchemaForEvent = options.getSchemaForEvent;
    const eventRepr         = options.eventRepr || makeEventRepr(options);

    // All header values will be truncated to this length to prevent malicious data.
    const maxHeaderLength = 400;

    // Used to split X-Forwarded-For header IP addresses
    const xffClientIpRegex = /,\s+/;

    /**
     * Given a request object, examines headers and socket remote addrs
     * to return a best guest at the requestor's client IP address.
     *
     * Choices in order of preferences:
     * - X-Client-IP header,
     * - Leftmost IP in X-Forwarded-For header
     * - req.socket.remoteAddress
     *
     * @param {http.ClientRequest} req
     * @return {string}
     */
    function getClientIp(req) {
        return req.headers['x-client-ip'] ||
            (
                req.headers['x-forwarded-for'] &&
                req.headers['x-forwarded-for'].split(xffClientIpRegex)[0]
            ) ||
            req.socket.remoteAddress;
    }

    return async (event, context = {}) => {
        // If event does not have schema_uri_field but
        // schema_uri_query_param was provided in request, set schema_uri_field in event.
        // NOTE: this assumes that schema_uri_field IS a valid field in the event's schema.
        // We'd like to check the schema to make sure that schema_uri_field is in the schema,
        // but we don't have the schema yet to do so.
        if (options.schema_uri_query_param &&
            !_.has(event, options.schema_uri_field) &&
            context.req.query[options.schema_uri_query_param]
        ) {
            _.set(
                event,
                options.schema_uri_field,
                context.req.query[options.schema_uri_query_param]
            );
            logger.trace(
                `Set ${options.schema_uri_field} to ` +
                `${context.req.query[options.schema_uri_query_param]} in ` +
                eventRepr(event, context)
            );
        }

        const schema = await getSchemaForEvent(event);

        // If event does not have stream_field but
        // stream_query_param was provided in request, set stream_field in event.
        // NOTE: this assumes that stream_field IS a valid field in the event's schema.
        if (options.stream_query_param &&
            !_.has(event, options.stream_field) &&
            context.req.query[options.stream_query_param]
        ) {
            _.set(
                event,
                options.stream_field,
                context.req.query[options.stream_query_param]
            );
            logger.trace(
                `Set ${options.stream_field} to ` +
                `${context.req.query[options.stream_query_param]} in ` +
                eventRepr(event, context)
            );
        }

        // meta.id ||= new uuidv1
        if (_.has(schema, 'properties.meta.properties.id') && !_.has(event, 'meta.id')) {
            _.set(event, 'meta.id', uuidv1());
            logger.trace(`Set meta.dt in ${eventRepr(event, context)}`);
        }

        const nowDt = new Date().toISOString();
        // meta.dt ||= now
        if (_.has(schema, 'properties.meta.properties.dt') && !_.has(event, 'meta.dt')) {
            _.set(event, 'meta.dt', nowDt);
            logger.trace(`Set meta.dt in ${eventRepr(event, context)}`);
        }
        // dt ||= now (For legacy EventLogging events.)
        // In non-legacy schemas, we expect dt to be a client side timestamp.
        // we only want to set this if this is a legacy EventLogging schema,
        // all of which are titled prefixed with 'analytics/legacy'.
        if (
            _.has(schema, 'title') && schema.title.startsWith('analytics/legacy') &&
            _.has(schema, 'properties.dt') && !_.has(event, 'dt')
        ) {
            _.set(event, 'dt', nowDt);
            logger.trace(`Set dt in ${eventRepr(event, context)}`);
        }

        // Use HTTP request info to set some more field defaults.
        // If we don't have it (likely because we are calling this directly in tests?)
        // just warn.
        if (!context.req) {
            logger.warn(
                `Cannot augment ${eventRepr(event, context)} with HTTP request info: ` +
                'req was not given in context parameter.'
            );
        } else {
            // meta.request_id ||= X-Request-ID header
            // http.request_headers['user-agent'] ||= User-Agent header
            _.forEach(options.http_request_headers_to_fields, (field, header) => {
                if (
                    (_.has(schema, fieldNameToSchemaName(field)) ||
                     _.get(schema, fieldNameToSchemaName(parentOfField(field)) + '.type') === 'object') &&
                    !_.has(event, field) &&
                    context.req.headers[header]
                ) {
                    _.set(
                        event, field,
                        context.req.headers[header].slice(0, Math.max(0, maxHeaderLength))
                    );
                    logger.trace(`Set ${field} in ${eventRepr(event, context)}`);
                }
            });

            // http.client_ip ||= getClientIp(context.req)
            if (
                _.has(schema, 'properties.http.properties.client_ip') &&
                !_.has(event, 'http.client_ip')
            ) {
                _.set(
                    event, 'http.client_ip',
                    getClientIp(context.req).slice(0, Math.max(0, maxHeaderLength))
                );
                logger.trace(`Set http.client_ip in ${eventRepr(event, context)}`);
            }
        }
        return event;
    };
}

/**
 * Returns a function that given an event, will ensure that it is allowed in a stream (optionally),
 * and that the event validates with its JSONSchema (using EventValidator).
 *
 * @param {Object} options
 * @param {Array<string>} options.schema_base_uris
 * @param {string} options.schema_uri_field
 * @param {string} options.stream_field
 * @param {boolean} options.allow_absolute_schema_uris
 * @param {string} options.stream_config_uri
 * @param {boolean} options.stream_config_ttl
 * @param {int} options.stream_config_retries
 * @param {Object} logger
 * @return {function(string): Object}
 */
async function makeEventValidator(options, logger) {
    // Use the already constructed functions if they are set in options, else
    // make them from options now.
    const extractSchemaUri = options.extractSchemaUri || makeExtractSchemaUri(options);
    let getSchema          = options.getSchema;

    if (!getSchema) {
        // First check if allow_absolute_schema_uris is false, and if it is, throw
        // an error if the event's uri starts with a protocol scheme.
        getSchema = (uri) => {
            // If we don't allow absolute schema URIs, then events shouldn't
            // ever have URIs that start with a URL protocol scheme.
            // If this one does, then throw and error and fail now.
            // (Protocol less URIs with domains are still assumed to be 'relative' by
            // resolveUri in event-utils, and will be prefixed with
            // schema_base_uris before they are searched.  So it is safe
            // to only check uriHasProtocol for URI absoluteness.)
            if (!options.allow_absolute_schema_uris && uriHasProtocol(uri)) {
                throw new Error(
                    `Absolute schema URIs are not allowed but event schema_uri is ${uri}`
                );
            }
            // Return the first schema found for URI by looking for it in each schema_base_uris.
            return uriGetFirstObject(uri, options.schema_base_uris, options.schema_file_extension);
        };
    }

    if (options.schema_base_uris) {
        logger.info(`Will look for relative schema_uris in ${options.schema_base_uris}`);
    }

    // This EventValidator instance will be used to validate all incoming events.
    const eventValidator = new EventValidator({
        extractSchemaUri,
        getSchema,
        log: logger
    });

    return eventValidator;
}

class UnauthorizedSchemaForStreamError extends Error {}

/**
 * Returns a function that given an event, will either return true, or throw
 * UnauthorizedSchemaForStreamError if the event is not allowed in its destined
 * stream.
 *
 * @param {Object} options
 * @param {string} options.stream_config_uri
 * @param {string} options.stream_config_uri_options
 * @param {int} options.stream_config_ttl
 * @param {int} options.stream_config_retries
 * @param {function(Object): Object} options.getSchemaForEvent
 *     Given an event, returns the event's JSONSchema.  This likely should be
 *     a bound EventValidator schemaFor function, so that
 *     any event schema lookups are always done in the same way, and cached.
 *     This option is required.
 * @param {function(Object, Object): Object} options.eventRepr
 * @param {Object} logger
 * @return {function(Object, Object): boolean}
 * @throws UnauthorizedSchemaForStreamError
 */
async function makeEnsureEventAllowedInStream(options, logger) {
    if (!options.stream_config_uri) {
        throw new Error('Must set options.stream_config_uri for makeEnsureEventAllowedInStream.');
    }
    if (!_.isFunction(options.getSchemaForEvent)) {
        throw new Error(
            'Must set options.getSchemaForEvent to a function for makeEnsureEventAllowedInStream.'
        );
    }

    // A schema's title field will be compared to value of the stream config schema_title
    const schemaTitleField = 'title';
    const streamConfigSchemaTitleField = 'schema_title';

    // Use the already constructed functions if they are set in options, else
    // make them from options now.
    const extractSchemaUri  = options.extractSchemaUri || makeExtractSchemaUri(options);
    const extractStream     = options.extractStream || makeExtractStream(options);
    const eventRepr         = options.eventRepr || makeEventRepr(options);
    const getSchemaForEvent = options.getSchemaForEvent;
    const streamConfigs     = options.streamConfigs || await makeStreamConfigs(options, logger);

    /**
     * Uses streamConfigs to verify that the event is allowed in stream.
     *
     * @param {Object} event
     * @throws {UnauthorizedSchemaForStreamError}
     * @return {boolean} true if the schema is allowed in stream.
     */
    return async (event) => {
        const stream = extractStream(event);

        // Load the event's schema.
        const schema    = await getSchemaForEvent(event);
        // Get the schema URI for logging purposes.
        const schemaUri = extractSchemaUri(event);

        // Get the title field out of the schema.  This must match
        // the allowed schema for this stream.
        const schemaTitle = objectGet(schema, schemaTitleField);
        if (_.isUndefined(schemaTitle)) {
            throw new UnauthorizedSchemaForStreamError(
                `Schema at ${schemaUri} must define a 'title' field. From ${eventRepr(event)}`
            );
        }

        let specificStreamConfig;
        try {
            specificStreamConfig = streamConfigs.get(stream);
        } catch (error) {
            throw new UnauthorizedSchemaForStreamError(
                `${eventRepr(event)} is not allowed in stream; ` +
                `got error when fetching stream config: ${error}`
            );
        }

        if (_.isUndefined(specificStreamConfig)) {
            throw new UnauthorizedSchemaForStreamError(
                `${eventRepr(event)} is not allowed in stream; ` +
                `${stream} is not configured.`
            );
        }

        // Sometimes we seem to get a stream config response with no schema_title setting.
        // To help debug this, throw a specific error if the stream config is actually empty.
        if (_.isEmpty(specificStreamConfig)) {
            throw new UnauthorizedSchemaForStreamError(
                `${eventRepr(event)} is not allowed in stream; ` +
                `${stream} is configured but does not have any settings.`
            );
        }

        const allowedSchemaTitle   = _.get(specificStreamConfig, streamConfigSchemaTitleField);
        if (_.isUndefined(allowedSchemaTitle)) {
            throw new UnauthorizedSchemaForStreamError(
                `${eventRepr(event)} is not allowed in stream; ` +
                `${stream} does not have a ${streamConfigSchemaTitleField} setting.`
            );
        }

        if (schemaTitle !== allowedSchemaTitle) {
            throw new UnauthorizedSchemaForStreamError(
                `${eventRepr(event)} is not allowed in stream; ` +
                `schema title must be ${allowedSchemaTitle}.`
            );
        }

        return true;
    };
}

/**
 * Creates a new schema URI based validate(event) function.
 * The returned function first checks the stream config to ensure that
 * the event's schema title is allowed in the event's destination stream.
 * It then uses an EventValidator instance to validate
 * the event against its schema.
 *
 * @param {Object} options
 * @param {string} options.stream_config_uri
 *      URI to a stream config file.  This file should contain
 *      a mapping of stream name to config, most importantly including
 *      the stream's allowed schema title.
 * @param {string} options.schema_uri_field
 *      Used to extract the event's schema URI.
 * @param {string} options.schema_base_uri
 *      If set, this is prefixed to un-anchored schema URIs.
 * @param {string} options.schema_file_extension
 *      If set, this is suffixed to schema URIs that dont' already have a file extension.
 * @param {Object} logger
 * @return {Function} EventGate validate function
 */
async function makeCustomValidate(options, logger) {
    // Use the already constructed functions if they are set in options, else
    // make them from options now.
    const eventValidator =  await makeEventValidator(options, logger);

    // eventValidator already knows how to get a schema for an event.
    // Reuse it in ensureEventAllowedInStream and setCustomDefaults functions.
    options.getSchemaForEvent = options.getSchemaForEvent ||
        eventValidator.schemaFor.bind(eventValidator);

    let ensureEventAllowedInStream;
    if (options.stream_config_uri) {
        ensureEventAllowedInStream = await makeEnsureEventAllowedInStream(options, logger);
    } else {
        logger.info(
            'No stream_config_uri was set; events of any $schema will be allowed in any stream.'
        );
    }

    // Before schema validation, the event will be transformed by this function
    // to ensure any custom (required) defaults that weren't set client side
    // are set now.
    const setCustomDefaults = makeSetCustomDefaults(options, logger);

    // Finally create a single validate function that
    // checks that an event's schema is allowed in a stream,
    // and that it validates against its schema.
    return async (event, context = {}) => {
        // Set any custom specific defaults that all events should have.
        event = await setCustomDefaults(event, context);

        if (ensureEventAllowedInStream) {
            // First ensure that this event schema is allowed in the destination stream.
            await ensureEventAllowedInStream(event);
        }

        // Then validate the event against its schema.
        return eventValidator.validate(event);
    };
}

/**
 * Returns the Kafka topic that events in this stream should be produced to.
 * If the stream starts with 'eventlogging_', we assume it is a legacy
 * EventLogging analytics stream.  These streams are older and don't use
 * any (datacenter) topic prefixes.  The topic name should match the stream name
 * exactly.
 *
 * Otherwise, if options.topic_prefix is set, this will return topic_prefix + stream,
 * else just stream will be used as the topic name.
 *
 * @param  {Object} options
 * @param  {string} options.topic_prefix
 * @param  {string} stream
 * @return {string}
 */
function getKafkaTopicForStream(options, stream) {
    if (stream.startsWith('eventlogging_') || !options.topic_prefix) {
        return stream;
    } else {
        return options.topic_prefix + stream;
    }
}

/**
 * Returns rdkafka conf and topic_conf by merging
 * options.kafka.{conf|topic_conf} and options.kafka[producerType].{conf|topic_conf}.
 * Allows for defaults in e.g. options.kafka.conf with producerType specific
 * overrides in options.kafka[producerType].  Also sets some defaults
 * like client.id if not provided.
 *
 * @param {Object} options
 * @param {Object} options.kafka.conf rdkafka conf
 * @param {Object} options.kafka.topic_conf rdkafka topic_conf
 * @param {Object} options.kafka.producerType.conf producerType specific rdkafka conf
 * @param {Object} options.kafka.producerType.topic_conf producerType specific rdkafka topic_conf
 * @param {string} producerType either 'hasty' or 'guarnteed'
 * @return {Object} {conf: {...}, topic_conf: {...}}
 */
function getKafkaProducerConf(options, producerType) {
    // Set a good identifiable default client.id.
    // This helps identify client connections on brokers.
    // Use the service user-agent and producerType in the guaranteed Kafka client.id
    const clientName = options.user_agent || 'eventgate';
    const kafkaConfDefaults = {
        'client.id': `${clientName}-producer-${producerType}`,
    };
    const kafkaTopicConfDefaults = {};

    const kafkaConf = _.defaultsDeep(
        {},
        _.get(options, `kafka.${producerType}.conf`, {}),
        _.get(options, 'kafka.conf', {}),
        kafkaConfDefaults
    );

    const kafkaTopicConf = _.defaultsDeep(
        {},
        _.get(options, `kafka.${producerType}.topic_conf`, {}),
        _.get(options, 'kafka.topic_conf', {}),
        kafkaTopicConfDefaults
    );

    return {
        conf: kafkaConf,
        topic_conf: kafkaTopicConf
    };
}

/**
 * Instantiates and connects either a guaranteed or hasty Kafka Producer
 * with logging and metrics configured.
 *
 * @param {Object} options
 * @param {Object} options.kafka
 * @param {Object} options.kafka.conf
 *      node-rdkafka KafkaProducer configuration
 * @param {Object} options.kafka.topic_conf
 *      node-rdkafka KafkaProducer topic configuration
 * @param {RdkafkaStats} options.rdKafkaPrometheus
 *      A node-rdkafka-prometheus RdKafkaStats instance.  If metrics is configured to
 *      use Prometheus but this is not set in options, a new RdKafkaStats instance
 *      will be created, and options.rdKafkaPrometheus will be set to it.
 *      This allows multiple calls to this function with the same options
 *      to share the same RdKafkaStats instance.
 * @param {string} producerType
 *      Either 'hasty' or 'guaranteed'.
 * @param {Object} logger
 * @param {Object} metrics
 *      service-runner metrics interface.  This is provided from
 *      service-runner app.
 * @return {Promise<Object>} connected Kafka Producer
 */
async function makeKafkaProducer(options, producerType, logger, metrics) {
    if (!['hasty', 'guaranteed'].includes(producerType)) {
        throw new Error(
            `Invalid producerType, must be one of 'hasty' or 'guaranteed': ${producerType}`
        );
    }

    const kafka = requireOptional('@wikimedia/node-rdkafka-factory');

    const {
        conf,
        // eslint-disable-next-line camelcase
        topic_conf
    } = getKafkaProducerConf(options, producerType);

    logger.info(
        // eslint-disable-next-line camelcase
        { conf, topic_conf },
        `Creating ${producerType} Kafka producer`
    );

    const ProducerClass = producerType === 'hasty' ?
        kafka.HastyProducer : kafka.GuaranteedProducer;

    const producer = await ProducerClass.factory(
        conf,
        topic_conf,
        logger
    );

    // Register rdkafka events.stats callback to expose metrics
    // via service-runner Metrics.
    if (metrics && conf['statistics.interval.ms']) {
        // List of callbacks to call when rdkafka events.stats is fired.
        const metricsCallbacks = [];

        // If service-runner metrics StatsDClient is being used, then
        // handle rdkafka metrics with node-rdkafka-statsd.
        if (metrics.fetchClient('StatsDClient')) {
            logger.info(
                'Enabling Kafka metrics reporting for ' +
                `${producerType} Kafka producer via statsd.`
            );
            const rdkafkaStatsd = requireOptional('node-rdkafka-statsd');
            const rdkafkaStatsdCb = rdkafkaStatsd(
                // NOTE: makeChild is deprecated, but
                // we'd need to rewrite node-rdkafka-statsd
                // to support the new service-runner
                // metrics.makeMetric interface.
                metrics.makeChild(`rdkafka.producer.${producerType}`)
            );
            metricsCallbacks.push(rdkafkaStatsdCb);
        }

        // If service-runner metrics Prometheus is being used, then
        // handle rdkafka metrics with node-rdkafka-prometheus.
        if (metrics.fetchClient('PrometheusClient')) {
            logger.info(
                'Enabling Kafka metrics reporting for ' +
                `${producerType} Kafka producer via prometheus.`
            );

            const RdkafkaPrometheus = requireOptional('@wikimedia/node-rdkafka-prometheus');
            const rdkafkaPrometheus = options.rdkafkaPrometheus || new RdkafkaPrometheus({
                // Pass prom-client to RdkafkaPrometheus constructor so it does
                // not have to require it itself. See:
                // https://github.com/siimon/prom-client/issues/199#issuecomment-556908200
                // https://github.com/siimon/prom-client/issues/448
                prometheus: metrics.fetchClient('PrometheusClient').client,
                // prefix metrics with eventgate_
                namePrefix: 'eventgate_',
                // producer_type label value will be set in the callback below.
                extraLabels: _.merge({ producer_type: '' }, metrics.getServiceLabel()),
            });

            // Save RdkafkaPrometheus instance we create in options for reuse if this
            // function is called again. This is necessary here because RdkafkaPrometheus
            // adds promethues metrics by name to the prom-client register, and
            // if the same metrics are added to the register again, an error will be thrown.
            // We only want to construct one RdkafkaPrometheus per prom-client register.
            options.rdkafkaPrometheus = rdkafkaPrometheus;

            metricsCallbacks.push((stats) => {
                rdkafkaPrometheus.observe(stats, { producer_type: producerType });
            });
        }

        // Call each defined metricsCallback on events.stats
        producer.on('event.stats', (msg) => {
            const stats = JSON.parse(msg.message);
            metricsCallbacks.forEach((cb) => cb(stats));
        });
    }

    return producer;
}

/**
 * Creates a message key object from fields in the event.
 *
 * @param {Object} event
 * @param {Object<string, string>} keyFieldToEventFieldMap
 *  This maps field paths in the key to field paths in the event.
 *  The key field will be set to the value of the event field.
 *  E.g. `{ key.fieldA: a.b.c }` will result in a message key
 *  returned like `{ key.fieldA: <value at event.a.b.c> }`
 * @return {Object} message key
 */
function createMessageKey(event, keyFieldToEventFieldMap) {
    return _.transform(
        keyFieldToEventFieldMap,
        (result, eventFieldPath, keyFieldPath) => {
            const value = _.get(event, eventFieldPath);
            if (value === undefined) {
                throw new Error(`Failed extracting ${keyFieldPath} from event, field is not defined.`);
            }
            _.set(result, keyFieldPath, value);
            return result;
        }
    );
}

/**
 * Creates a function that returns a Kafka produce function
 * suitable for passing to EventGate as the produce function argument.
 * This conditionally uses either a GuaranteedProducer or a HastyProducer
 * depending on the value of the context.req.query.hasty request query parameter.
 *
 * @param {Object} options
 * @param {string} options.stream_field
 *      Used to extract the event's destination stream name.
 * @param {string} options.dt_field
 *      If given, this field will be extracted as a string ISO-8601 datetime,
 *      and used as the Kafka message timestamp.
 * @param {string} options.topic_prefix
 *      If given, this will be prefixed to the value extracted from stream_field
 *      and used as the topic in Kafka.
 * @param {Object} metrics service-runner metrics interface.  This is provided from
 *      service-runner app.
 *      This is optional, and will only be used if context.req.query.hasty is set to true.
 * @param {Object} logger
 * @return {Promise<Function>} Promise of EventGate produce function
 */
async function makeProduce(options, metrics, logger) {
    // Use the already constructed functions if they are set in options, else
    // make them from options now.
    const extractStream = options.extractStream || makeExtractStream(options);
    const extractSchemaUri = options.extractSchemaUri || makeExtractSchemaUri(options);

    let streamConfigs;
    if (options.stream_config_uri) {
        streamConfigs = options.streamConfigs || await makeStreamConfigs(options, logger);
    }

    // Use extractTimestamp if provided in options (usually for testing), else
    // if options.dt_field is provied, use it to make an extractTimestamp function.
    let extractTimestamp = options.extractTimestamp;
    if (!extractTimestamp && options.dt_field) {
        extractTimestamp = makeExtractTimestamp(options);
    }

    // Create both a GuaranteedProducer and a HastyProducer.
    // Which one is used during produce() is determined by the
    // req.query.hasty parameter.
    const hastyProducer      = await makeKafkaProducer(options, 'hasty', logger, metrics);
    const guaranteedProducer = await makeKafkaProducer(options, 'guaranteed', logger, metrics);

    let produceMetric;
    if (metrics) {
        produceMetric = metrics.makeMetric({
            type: 'Counter',
            name: 'events.produced',
            prometheus: {
                name: 'eventgate_events_produced_total',
                help: 'EventGate events produced',
                staticLabels: metrics.getServiceLabel(),
            },
            labels: {
                names: ['stream', 'schema_uri'],
            },
        });
    }

    // Return a new function that takes a single event argument for produce.
    return async (event, context = {}) => {
        const stream = extractStream(event);

        let timestamp;
        if (extractTimestamp) {
            timestamp = extractTimestamp(event, context);
        }

        if (produceMetric) {
            const schemaUri = extractSchemaUri(event);
            produceMetric.increment(1, [stream, schemaUri]);
        }

        const topic = getKafkaTopicForStream(options, stream);
        const serializedEvent = Buffer.from(JSON.stringify(event));

        let serializedKey;
        if (streamConfigs) {
            const streamSettings = streamConfigs.get(stream);
            if (streamSettings && streamSettings.message_key_fields) {
                const messageKey = createMessageKey(event, streamSettings.message_key_fields);
                serializedKey = Buffer.from(JSON.stringify(messageKey));
            }
        }

        // Use hasty non-guaranteed producer if this event was submitted
        // using via HTTP with the ?hasty query parameter set to true.
        if (hastyProducer && _.get(context, 'req.query.hasty', false)) {
            return hastyProducer.produce(
                topic, undefined, serializedEvent, serializedKey, timestamp
            );
        } else {
            return guaranteedProducer.produce(
                topic, undefined, serializedEvent, serializedKey, timestamp
            );
        }
    };
}

/**
 * Returns a Promise of an instantiated EventGate that uses EventValidator
 * and event schema URL lookup and Kafka to produce messages.  error events
 * will be created and produced upon ValidationErrors.
 *
 * @param {Object} options
 * @param {string} options.schema_uri_field
 *      Used to extract the event's schema URI.
 * @param {string} options.schema_base_uri
 *      If set, this is prefixed to un-anchored schema URIs.
 * @param {string} options.schema_file_extension
 *      If set, this is suffixed to schema URIs that dont' already have a file extension.
 * @param {string} options.id_field
 *      Used to extract the event's 'id'. This field will be used as the event's 'id' in log
 *      messages
 * @param {string} options.stream_field
 *      Used to extract the event's destination stream name.
 * @param {string} options.topic_prefix
 *      If given, this will be prefixed to the value extracted from stream_field
 *      and used as the topic in Kafka.
 * @param {Object} options.kafka
 * @param {Object} options.kafka.conf
 *      node-rdkafka KafkaProducer configuration
 * @param {Object} options.kafka.topic_conf
 *      node-rdkafka KafkaProducer topic configuration
 * @param {Object} logger
 * @param {Object} metrics service-runner metrics interface.  This is provided from
 *      service-runner app.
 * @param {Object} router Express router object.  Useful if you want to add extra http routes
 *      to the EventGate service route.
 * @return {Promise<EventGate>}
 */
async function customEventGateFactory(options, logger, metrics, router) {
    _.defaultsDeep(options, defaultOptions);

    // Premake some of the event handling functions so that that they
    // can use each other without having to each make duplicate functions.
    // Each of the above make* functions will check options
    // to see if a function they would use is already set.
    options.extractSchemaUri = makeExtractSchemaUri(options);
    options.extractStream    = makeExtractStream(options);
    options.eventRepr        = makeEventRepr(options);

    // Premake streamConfigs so we can use it to export known
    // stream configs in an HTTP route for easier inspection of running service config.
    if (options.stream_config_uri) {
        options.streamConfigs = await makeStreamConfigs(options, logger);

        // Add extra GET stream-configs routes to export cached stream configs
        logger.debug(
            'Adding /stream-configs HTTP route to expose stream configs ' +
            'fetched from ' + options.stream_config_uri
        );

        // Split streams param on , or |
        // | is used by MW API EventStreamConfig, and it will be easier for
        // clients to format URLs with stream names if they can do so the
        // same way for both APIs.
        const streamsSeparatorPattern = /[,|]/;
        router.get('/stream-configs/:streams?', async (req, res) => {
            // Either get the requested streams, or return
            // all cached stream configs.
            const requestedStreams = req.params.streams ?
                req.params.streams.split(streamsSeparatorPattern) :
                options.streamConfigs.keys();

            // Get requested stream configs and filter out any streams that are not configured.
            // _.pickBy will remove elements from the object that have falsey values.
            const result =  _.pickBy(options.streamConfigs.mget(requestedStreams));

            res.status(200);
            res.json(result);
        });
    }

    const validate = await makeCustomValidate(options, logger);
    const produce = await makeProduce(options, metrics, logger);

    return new EventGate({
        validate,
        produce,
        eventRepr: makeEventRepr(options),
        log: logger,
        mapToErrorEvent: makeMapToErrorEvent(options, metrics)
    });
}

module.exports = {
    factory: customEventGateFactory,
    makeMapToErrorEvent,
    makeEventRepr,
    makeExtractStream,
    makeCustomValidate,
    makeSetCustomDefaults,
    makeProduce,
    defaultOptions,
    UnauthorizedSchemaForStreamError,
};

if (require.main === module) {
    const start = async () => {
        let conf;
        // If not specifying a config file on the CLI, then we want to use
        // the included config file, but make sure that the evengate_factory_module
        // is set to use this exact file.  Read in the config file manually and
        // set it, then pass the read in config directly to service-runner.
        if (!process.argv.includes('-c') && !process.argv.includes('--config')) {
            const configFile = `${__dirname}/config.yaml`;

            conf = await urlGetObject(configFile);
            conf.services[0].conf.eventgate_factory_module = require.main.filename;
        }

        const ServiceRunner = require('service-runner');
        return new ServiceRunner().start(conf);
    };

    start();
}
