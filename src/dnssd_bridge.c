/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#include "dnssd_bridge.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <arpa/inet.h>
#include <dns_sd.h>


struct ResourceRecord {
  struct ResourceRecord *next;
  const char *fullname;
  const char *address;
  uint16_t rrtype;
  uint16_t rrclass;
  uint32_t ttl;
};

#define RECORD_FIELD_GETTER(type, suffix, field, default) \
type \
record##suffix (struct ResourceRecord *record) \
{ \
  return record ? record->field : default; \
}
RECORD_FIELD_GETTER(struct ResourceRecord *, Next, next, NULL)
RECORD_FIELD_GETTER(const char *, Fullname, fullname, "")
RECORD_FIELD_GETTER(const char *, Address, address, "")
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

int32_t
queryResultError(struct QueryResult *result)
{
  return result ? result->error : 0;
}

struct ResourceRecord *
queryResultRecordList(struct QueryResult *result)
{
  return result ? result->records : NULL;
}


static void
resourceRecordFree(struct ResourceRecord *record)
{
  if (!record) return;

  free((char *)record->fullname);
  free((char *)record->address);
  free(record);
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
    next = record->next;
    resourceRecordFree(record);
  }
  free(result);
}


struct QueryContext {
  /* Owned by |synchronouslyQueryRecord|, borrowed by |consQueryRecord|. */
  struct QueryResult *result;

  /* Set by |consQueryRecord| to terminate the select loop. */
  bool stop_waiting;
};


static void
consQueryRecord(
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
    void                                *untyped_context
)
{
  fprintf(stderr, "%s: flags: %08x - interface %"PRIu32" - errorCode %"PRId32
      " - fullname %s - rdlen %"PRIu16" - rdata $%p - ttl %"PRIu32"\n",
      __func__, flags, interfaceIndex, errorCode,
      fullname, rdlen, rdata, ttl);

  struct QueryContext *context = untyped_context;

  bool are_more_results_coming = ((flags & kDNSServiceFlagsMoreComing)
      == kDNSServiceFlagsMoreComing);
  if (!are_more_results_coming) {
    context->stop_waiting = true;
  }

  bool should_add_result = ((flags & kDNSServiceFlagsAdd) == kDNSServiceFlagsAdd);
  if (!should_add_result) {
    return;
  }

  struct ResourceRecord *record = calloc(1, sizeof(*record));
  record->rrtype = rrtype;
  record->rrclass = rrclass;
  record->ttl = ttl;

  const size_t name_length = strlen(fullname);
  const size_t name_buffer_size = name_length + 1;
  char *name_buffer = calloc(1, name_buffer_size);
  // ignore return value - our buffer is sized based on the strlen already
  (void)strlcpy(name_buffer, fullname, name_buffer_size);
  record->fullname = name_buffer;

  const bool is_ipv4 = (rrtype == kDNSServiceType_A);
  const size_t address_buffer_size = (is_ipv4
      ? INET_ADDRSTRLEN
      : INET6_ADDRSTRLEN);
  char *address_buffer = calloc(1, address_buffer_size);
  const int address_family = is_ipv4 ? AF_INET : AF_INET6;
  record->address = inet_ntop(
      address_family, rdata, address_buffer, address_buffer_size);
  fprintf(stderr, "%s: address is: %s\n", __func__, record->address);

  struct QueryResult *result = context->result;
  record->next = result->records;
  result->records = record;
}


struct QueryResult *
synchronouslyQueryRecord(
  const char *fullname, uint16_t resourceRecordType, uint16_t resourceRecordClass)
{
  struct QueryResult *result = calloc(1, sizeof(*result));
  struct QueryContext context = {.result = result, .stop_waiting = false};
  DNSServiceRef sdRef = NULL;
  DNSServiceErrorType error = DNSServiceQueryRecord(
    &sdRef, kDNSServiceFlagsTimeout, kDNSServiceInterfaceIndexAny,
    fullname, resourceRecordType, resourceRecordClass,
    consQueryRecord, &context);
  if (error) {
    result->is_error = true;
    result->error = error;
    fprintf(stderr, "%s: DNSServiceQueryRecord: error %"PRId32"\n", __func__, error);
    return result;
  }


#define USE_SIMPLER_BLOCKING_APPROACH 1
#if USE_SIMPLER_BLOCKING_APPROACH
for (;;) {
  fprintf(stderr, "%s: waiting on DNSServiceProcessResult\n", __func__);
  DNSServiceErrorType error = DNSServiceProcessResult(sdRef);

  if (error) {
    bool should_ignore_error = (error = kDNSServiceErr_Timeout
      || result->records != NULL);
    if (!should_ignore_error) {
      result->is_error = true;
      result->error = error;
      fprintf(stderr, "%s: DNSServiceProcessResult: error %"PRId32"\n", __func__, error);
    }
    break;
  }

  if (context.stop_waiting) {
    break;
  }
}
#else
  fd_set read_fdset;
  fd_set error_fdset;
  int service_fd = DNSServiceRefSockFD(sdRef);
  for (;;) {
    FD_CLR(&read_fdset);
    FD_SET(service_fd, &read_fdset);
    FD_COPY(&read_fdset, &error_fdset);

    /* TODO: fill in timeval with a max timeout, otherwise, why bother with select? */
    int nready = select(service_fd + 1, read_fdset, NULL, read_fdset, NULL);

    bool did_error = nready < 0;
    if (did_error) {
      bool is_temporary_error = errno == EINTR || errno == EAGAIN;
      if (is_temporary_error) {
        continue;
      }
      perror("select")
      break;
    }

    bool is_readable = FD_ISSET(service_fd, &read_fdset);
    if (is_readable) {
      DNSServiceErrorType error = DNSServiceProcessResult(sdRef);
      if (error) {
        break;
      }
      if (context.stop_waiting) {
        break;
      }
    }
  }
#endif  // USE_SIMPLER_BLOCKING_APPROACH

  DNSServiceRefDeallocate(sdRef);
  return result;
}
