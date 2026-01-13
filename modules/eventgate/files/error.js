'use strict';

/**
 * eventgate-wikimedia defined error classes and event error handler.
 * Errors subclass from EventGate's ContextualError class.
 */

const _ = require('lodash');
const uuid = require('uuid');

const ContextualError = require('./src/lib/error.js').ContextualError;
const ValidationError = require('./src/lib/error.js').ValidationError;

/**
 * The schema URI of the error event that will be created and produced
 * for event validation errors.  Change this when you change
 * error schema versions.
 */
const errorEventSchemaUri = '/error/2.1.0';

class UnauthorizedSchemaForStreamError extends ContextualError {}

class MalformedHeaderError extends ContextualError {}

// Used to distinguish vaidation errors specifically
// by the experiment hoisting mechanism
class HoistingError extends ContextualError {}

/**
 * Error type names for which error events will be returned by
 * the function returned by makeMapToErrorEvent.
 *
 * Note that this uses the string name of the type classes, not the
 * types themselves. instanceof is not used, so you cannot use a parent
 * class to catch all subclass types.
 *
 * TODO: Rather than hardcoding types of errors here,
 * consider making a new `options.error_stream_allowed_error_types` config
 */
const errorStreamAllowedErrorTypes = [
    ValidationError.name,
    HoistingError.name,
    MalformedHeaderError.name,
];

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

/**
 * Returns a new mapToErrorEvent function that uses options.error_schema_uri
 * and options.error_stream to return an error event that conforms to the
 * error event schema used by Wikimedia.  This function only returns
 * error events for ValidationErrors and HoistingErrors.
 *
 * The returned function also handles emitting metrics about encountered errors.
 *
 * The returned function is intended to be used for
 * EventGate's constructor mapToErrorEvent parameter.
 *
 * @param {Object} options
 * @param {Object} metrics service-utils metrics interface.
 * @return {function(Object, Object, Object): Object}
 */
function makeMapToErrorEvent(options, metrics) {
    let eventErrorMetric;
    if (metrics) {
        eventErrorMetric = metrics.createMetric({
            type: 'Counter',
            // Note: This metric has error_type as a label, and as of T398922
            // includes a bit more than strictly schema ValidationErrors.
            // It would be nice to rename this metric to something more generic.
            // `eventgate_event_errors_total` perhaps?
            name: 'eventgate_validation_errors_total',
            help: 'EventGate errors encountered during event validation or processing steps',
            labels: {
                names: ['service', 'stream', 'schema_uri', 'error_type'],
            },
        });
    }

    // Save the configured schema_uri_field and stream_field names for reference later.
    /* eslint-disable */
    const schemaUriField =_.isArray(options.schema_uri_field) ?
        options.schema_uri_field[0] :
        options.schema_uri_field;
    const streamField = _.isArray(options.stream_field) ?
        options.stream_field[0] :
        options.stream_field;
    /* eslint-enable */

    return (error, event, context = {}) => {
        // If the event that caused the error is an object,
        // we should be able to include
        // top level infomration in our error event about
        // the stream name and schema of the offending event.
        let erroredSchemaUri = 'unknown';
        let erroredStreamName = 'unknown';
        if (_.isObject(event)) {
            erroredSchemaUri = _.get(event, schemaUriField, 'unknown');
            erroredStreamName = _.get(event, streamField, 'unknown');
        }

        // errorEvent will be returned.
        // If returned as null, no error event will be produced.
        let errorEvent = null;

        // (If error_stream is configured and
        // this is an error that should be produced to the error stream)
        if (
            options.error_stream &&
            _.includes(errorStreamAllowedErrorTypes, error.name)
        ) {
            const now = new Date();

            errorEvent = {
                meta: {
                    id: uuid(),
                    uri: getToString(event, 'meta.uri', 'unknown'),
                    domain: getToString(event, 'meta.domain', 'unknown'),
                    request_id: getToString(event, 'meta.request_id', 'unknown')
                },
                dt: now.toISOString(),
                emitter_id: options.user_agent || 'eventgate-service',
                raw_event: _.isString(event) ? event : JSON.stringify(event),
                errored_schema_uri: erroredSchemaUri,
                errored_stream_name: erroredStreamName
            };

            if ('errorsText' in error) {
                // ValidationErrors have a custom errorsText. Use it as error message field.
                errorEvent.message = error.errorsText;
            } else {
                errorEvent.message = error.message;
            }

            // Set the schema_uri_field and
            // stream_field on the on the new error event.
            // (Note: _.set is used because the field names are configurable.)
            _.set(errorEvent, schemaUriField, errorEventSchemaUri);
            _.set(errorEvent, streamField, options.error_stream);

            // error.name should be set for subclasses of
            // EventGate's ContextualError, like ValidationError.
            // Use it for error_type.
            if (error.name) {
                errorEvent.error_type = error.name;
            }
        }

        if (eventErrorMetric) {
            // Increment error counter metric for this stream.
            eventErrorMetric.inc(
                // Labels: service, stream, schema_uri, error_type
                {
                    ...metrics.getServiceLabel(),
                    stream: erroredStreamName,
                    schema_uri: erroredSchemaUri,
                    error_type: error.name
                },
                1
            );
        }

        return errorEvent;
    };
}

module.exports = {
    UnauthorizedSchemaForStreamError,
    MalformedHeaderError,
    HoistingError,
    errorEventSchemaUri,
    makeMapToErrorEvent,
};
