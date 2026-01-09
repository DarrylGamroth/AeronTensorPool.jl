cmake_minimum_required(VERSION 3.16)
project(tensorpool_client C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

option(TP_BUILD_EXAMPLES "Build C client examples" ON)
option(TP_BUILD_TESTS "Build C client tests" OFF)
option(TP_BUILD_INTEGRATION_TESTS "Build C client integration tests" OFF)
option(TP_USE_BUNDLED_AERON "Use vendored Aeron C client" ON)

if (TP_USE_BUNDLED_AERON)
    add_subdirectory(vendor/aeron)
    set(TP_AERON_TARGET aeron)
else ()
    find_library(TP_AERON_TARGET aeron)
    if (NOT TP_AERON_TARGET)
        message(FATAL_ERROR "Aeron library not found; set TP_USE_BUNDLED_AERON=ON or provide libaeron")
    endif ()
endif ()

add_library(tensorpool_client STATIC
    src/tp_attach.c
    src/tp_client.c
    src/tp_consumer.c
    src/tp_context.c
    src/tp_detach.c
    src/tp_driver_control.c
    src/tp_errors.c
    src/tp_keepalive.c
    src/tp_qos.c
    src/tp_metadata.c
    src/tp_discovery.c
    src/tp_producer.c
    src/tp_shm.c)

target_include_directories(tensorpool_client
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/gen/wire
        ${CMAKE_CURRENT_SOURCE_DIR}/gen/driver
        ${CMAKE_CURRENT_SOURCE_DIR}/gen/discovery)

target_include_directories(tensorpool_client
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src)

target_link_libraries(tensorpool_client PRIVATE ${TP_AERON_TARGET})

if (TP_BUILD_EXAMPLES)
    add_executable(tp_attach_example examples/tp_attach_example.c)
    target_link_libraries(tp_attach_example PRIVATE tensorpool_client)
    add_executable(tp_producer_example examples/tp_producer_example.c)
    target_link_libraries(tp_producer_example PRIVATE tensorpool_client)
    add_executable(tp_consumer_example examples/tp_consumer_example.c)
    target_link_libraries(tp_consumer_example PRIVATE tensorpool_client)
    add_executable(tp_discovery_example examples/tp_discovery_example.c)
    target_link_libraries(tp_discovery_example PRIVATE tensorpool_client)
    add_executable(tp_qos_monitor_example examples/tp_qos_monitor_example.c)
    target_link_libraries(tp_qos_monitor_example PRIVATE tensorpool_client)
    add_executable(tp_consumer_progress_example examples/tp_consumer_progress_example.c)
    target_link_libraries(tp_consumer_progress_example PRIVATE tensorpool_client)
    add_executable(tp_consumer_rate_limit_example examples/tp_consumer_rate_limit_example.c)
    target_link_libraries(tp_consumer_rate_limit_example PRIVATE tensorpool_client)
    add_executable(tp_detach_example examples/tp_detach_example.c)
    target_link_libraries(tp_detach_example PRIVATE tensorpool_client)
    add_executable(tp_reattach_example examples/tp_reattach_example.c)
    target_link_libraries(tp_reattach_example PRIVATE tensorpool_client)
    add_executable(tp_invoker_example examples/tp_invoker_example.c)
    target_link_libraries(tp_invoker_example PRIVATE tensorpool_client)
endif ()

if (TP_BUILD_TESTS)
    enable_testing()
    add_executable(tp_superblock_test tests/tp_superblock_test.c)
    target_link_libraries(tp_superblock_test PRIVATE tensorpool_client)
    target_include_directories(tp_superblock_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_superblock_test COMMAND tp_superblock_test)
    add_executable(tp_shm_validate_test tests/tp_shm_validate_test.c)
    target_link_libraries(tp_shm_validate_test PRIVATE tensorpool_client)
    target_include_directories(tp_shm_validate_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_shm_validate_test COMMAND tp_shm_validate_test)
    add_executable(tp_qos_test tests/tp_qos_test.c)
    target_link_libraries(tp_qos_test PRIVATE tensorpool_client)
    target_include_directories(tp_qos_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_qos_test COMMAND tp_qos_test)
    add_executable(tp_metadata_test tests/tp_metadata_test.c)
    target_link_libraries(tp_metadata_test PRIVATE tensorpool_client)
    target_include_directories(tp_metadata_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_metadata_test COMMAND tp_metadata_test)
    add_executable(tp_metadata_api_test tests/tp_metadata_api_test.c)
    target_link_libraries(tp_metadata_api_test PRIVATE tensorpool_client)
    target_include_directories(tp_metadata_api_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_metadata_api_test COMMAND tp_metadata_api_test)
    add_executable(tp_discovery_test tests/tp_discovery_test.c)
    target_link_libraries(tp_discovery_test PRIVATE tensorpool_client)
    target_include_directories(tp_discovery_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_discovery_test COMMAND tp_discovery_test)
    add_executable(tp_shm_uri_test tests/tp_shm_uri_test.c)
    target_link_libraries(tp_shm_uri_test PRIVATE tensorpool_client)
    target_include_directories(tp_shm_uri_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_shm_uri_test COMMAND tp_shm_uri_test)
    add_executable(tp_attach_validate_test tests/tp_attach_validate_test.c)
    target_link_libraries(tp_attach_validate_test PRIVATE tensorpool_client)
    target_include_directories(tp_attach_validate_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_attach_validate_test COMMAND tp_attach_validate_test)
    add_executable(tp_control_progress_test tests/tp_control_progress_test.c)
    target_link_libraries(tp_control_progress_test PRIVATE tensorpool_client)
    target_include_directories(tp_control_progress_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_control_progress_test COMMAND tp_control_progress_test)
    add_executable(tp_getters_not_found_test tests/tp_getters_not_found_test.c)
    target_link_libraries(tp_getters_not_found_test PRIVATE tensorpool_client)
    target_include_directories(tp_getters_not_found_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_getters_not_found_test COMMAND tp_getters_not_found_test)
    add_executable(tp_accessors_test tests/tp_accessors_test.c)
    target_link_libraries(tp_accessors_test PRIVATE tensorpool_client)
    target_include_directories(tp_accessors_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_accessors_test COMMAND tp_accessors_test)
    add_executable(tp_consumer_empty_payload_test tests/tp_consumer_empty_payload_test.c)
    target_link_libraries(tp_consumer_empty_payload_test PRIVATE tensorpool_client)
    target_include_directories(tp_consumer_empty_payload_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_consumer_empty_payload_test COMMAND tp_consumer_empty_payload_test)
endif ()

if (TP_BUILD_INTEGRATION_TESTS)
    add_executable(tp_integration_smoke tests/tp_integration_smoke.c)
    target_link_libraries(tp_integration_smoke PRIVATE tensorpool_client)
    target_include_directories(tp_integration_smoke PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_integration_smoke COMMAND tp_integration_smoke)
    set_tests_properties(tp_integration_smoke PROPERTIES ENVIRONMENT "TP_STREAM_ID=10000;TP_ATTACH_TIMEOUT_MS=30000")
    add_executable(tp_integration_detach tests/tp_integration_detach.c)
    target_link_libraries(tp_integration_detach PRIVATE tensorpool_client)
    target_include_directories(tp_integration_detach PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/aeron)
    add_test(NAME tp_integration_detach COMMAND tp_integration_detach)
    set_tests_properties(tp_integration_detach PROPERTIES ENVIRONMENT "TP_STREAM_ID=10000;TP_ATTACH_TIMEOUT_MS=30000;TP_DETACH_TIMEOUT_MS=30000")
endif ()
