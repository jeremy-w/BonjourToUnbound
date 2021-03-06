/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#include <inttypes.h>
#include <stdbool.h>


/** synchronouslyQueryRecord blocks till all responses to a query for the specified
 *  DNS records complete, or until a default timeout expires, whichever comes first.
 *
 *  As of OS X 10.10.5, the default timeout appears to be thirty seconds.
 *
 *  The return value can be examined using the queryResult* functions in order to
 *  discover the result of the query (success with zero or more records
 *  or failure due to an error). */
struct QueryResult *synchronouslyQueryRecord(
  const char *fullname, uint16_t resourceRecordType, uint16_t resourceRecordClass);


/** queryResultIsError is used to discriminate between success and failure.
 *  If true, then use queryResultError to retrieve the result; otherwise, use
 *  queryResultRecordList to get the head of the result record list. */
bool queryResultIsError(struct QueryResult *result);

/** queryResultError returns the kDNSServiceErr_* value returned by the underlying
 *  system. The raw type is used to save you looking up what the typedef resolves to
 *  when calling this function through FFI. */
int32_t queryResultError(struct QueryResult *result);

/** queryResultRecordList returns the head of the result list.
 *
 *  If NULL, then the list is empty, meaning the query successfully found all zero
 *  matching records.
 *
 *  If non-NULL, then use the record* functions to destructure the record. */
struct ResourceRecord *queryResultRecordList(struct QueryResult *result);


#define RECORD_FIELD_GETTER(type, suffix, field, default) \
type record##field (struct ResourceRecord *record);
RECORD_FIELD_GETTER(struct ResourceRecord *, Next, next, NULL)
RECORD_FIELD_GETTER(const char *, Fullname, fullname, "")
RECORD_FIELD_GETTER(const char *, Address, address, "")
RECORD_FIELD_GETTER(uint16_t, RRType, rrtype, 0)
RECORD_FIELD_GETTER(uint16_t, RRClass, rrclass, 0)
RECORD_FIELD_GETTER(uint32_t, TTL, ttl, 0)
#undef RECORD_FIELD_GETTER
