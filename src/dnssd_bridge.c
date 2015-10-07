#include <inttypes.h>
#include <stdlib.h>
#include <dns_sd.h>

struct ResourceRecord {
  struct ResourceRecord **next;
  const char *fullname;
  uint16_t rrtype;
  uint16_t rrclass;
  uint32_t ttl;
};

struct ResourceRecord *
recordNext(struct ResourceRecord *record)
{
  return record ? *(record->next) : NULL;
}

#define RECORD_FIELD_GETTER(type, suffix, field, default) \
type \
record##suffix (struct ResourceRecord *record) \
{ \
  return record ? record->field : default; \
}
//RECORD_FIELD_GETTER(struct ResourceRecord *, Next, next, NULL)
RECORD_FIELD_GETTER(const char *, Fullname, fullname, "")
RECORD_FIELD_GETTER(uint16_t, RRType, rrtype, 0)
RECORD_FIELD_GETTER(uint16_t, RRClass, rrclass, 0)
RECORD_FIELD_GETTER(uint32_t, TTL, ttl, 0)
#undef RECORD_FIELD_GETTER

struct QueryResult {
  bool is_error;
  DNSServiceErrorType error;
  struct ResourceRecord *records;
};

bool
queryResultIsError(struct QueryResult *result)
{
  return result ? result->is_error : false;
}

uint32_t
queryResultError(struct QueryResult *result)
{
  return result ? result->error : 0;
}

struct ResourceRecord *
queryResultRecordList(struct QueryResult *result)
{
  return result ? result->records : NULL;
}

void
queryResultFree(struct QueryResult *result)
{
  if (!result) return;

  if (result->is_error) {
    free(result);
    return;
  }

  /* Walk the list, and for each node, read the next pointer, then free the current node. */
  for (struct ResourceRecord *record = result->records, *next = NULL;
    record != NULL; record = next) {
    next = *(record->next);
    free(record);
  }
  free(result);
}

struct QueryContext {
  /* Owned by |synchronouslyQueryRecord|, borrowed by |appendResponse|. */
  struct QueryResult *result;

  /* Set by |appendResponse| to terminate the select loop. */
  bool stop_waiting;
};

void
appendResponse(
    DNSServiceRef sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char                          *fullname,
    uint16_t rrtype,
    uint16_t rrclass,
    uint16_t rdlen,
    const void                          *rdata,
    uint32_t ttl,
    void                                *context
)
{
  /* TODO: implement */
}

struct QueryResult *
synchronouslyQueryRecord(
  const char *fullname, uint16_t resourceRecordType, uint16_t resourceRecordClass)
{
  struct QueryResult *result = malloc(sizeof(*result));
  DNSServiceRef sdRef = NULL;
  DNSServiceErrorType error = DNSServiceQueryRecord(
    &sdRef, kDNSServiceFlagsTimeout, kDNSServiceInterfaceIndexAny,
    fullname, resourceRecordType, resourceRecordClass,
    appendResponse, result);
  if (error) {
    result->is_error = true;
    result->error = error;
    return result;
  }

  int read_fd = DNSServiceRefSockFD(sdRef);
  /* TODO: select till readable, then drain */
  result->is_error = true;
  result->error = kDNSServiceErr_NotInitialized;
  DNSServiceRefDeallocate(sdRef);
  return result;
}
