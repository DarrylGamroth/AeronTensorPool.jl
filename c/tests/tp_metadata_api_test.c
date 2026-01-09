#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

int main(void)
{
    tp_producer_t producer;
    memset(&producer, 0, sizeof(producer));

    uint32_t version = 0;
    assert(tp_producer_metadata_version(&producer, &version) == TP_OK);
    assert(version == 0);

    assert(tp_producer_announce_data_source(&producer, "camera-1", "summary") == TP_OK);
    assert(tp_producer_metadata_version(&producer, &version) == TP_OK);
    assert(version == 1);
    assert(strcmp(producer.metadata_name, "camera-1") == 0);
    assert(strcmp(producer.metadata_summary, "summary") == 0);
    assert(producer.metadata_dirty);

    tp_metadata_attribute_t attrs[1];
    memset(attrs, 0, sizeof(attrs));
    snprintf(attrs[0].key, sizeof(attrs[0].key), "%s", "pattern");
    snprintf(attrs[0].mime_type, sizeof(attrs[0].mime_type), "%s", "text/plain");
    attrs[0].value_len = 7;
    memcpy(attrs[0].value, "counter", attrs[0].value_len);

    assert(tp_producer_set_metadata_attributes(&producer, attrs, 1) == TP_OK);
    assert(tp_producer_metadata_version(&producer, &version) == TP_OK);
    assert(version == 2);
    assert(producer.metadata_attr_count == 1);
    assert(strcmp(producer.metadata_attrs[0].key, "pattern") == 0);

    assert(tp_producer_set_metadata_attribute(
        &producer,
        "pattern",
        "text/plain",
        (const uint8_t *)"counter-2",
        9) == TP_OK);
    assert(tp_producer_metadata_version(&producer, &version) == TP_OK);
    assert(version == 3);
    assert(producer.metadata_attrs[0].value_len == 9);
    assert(memcmp(producer.metadata_attrs[0].value, "counter-2", 9) == 0);

    assert(tp_producer_delete_metadata_attribute(&producer, "pattern") == TP_OK);
    assert(tp_producer_metadata_version(&producer, &version) == TP_OK);
    assert(version == 4);
    assert(producer.metadata_attr_count == 0);

    assert(tp_producer_delete_metadata_attribute(&producer, "missing") == TP_ERR_NOT_FOUND);

    return 0;
}
