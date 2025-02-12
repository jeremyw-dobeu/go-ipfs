#!/usr/bin/env bash

test_description="Test HTTP Gateway Raw Block (application/vnd.ipld.raw) Support"

. lib/test-lib.sh

test_init_ipfs
test_launch_ipfs_daemon_without_network

test_expect_success "Create text fixtures" '
  mkdir -p dir &&
  echo "hello application/vnd.ipld.raw" > dir/ascii.txt &&
  ROOT_DIR_CID=$(ipfs add -Qrw --cid-version 1 dir) &&
  FILE_CID=$(ipfs resolve -r /ipfs/$ROOT_DIR_CID/dir/ascii.txt | cut -d "/" -f3)
'

# GET unixfs dir root block and compare it with `ipfs block get` output

    test_expect_success "GET with format=raw param returns a raw block" '
    ipfs block get "/ipfs/$ROOT_DIR_CID/dir" > expected &&
    curl -sX GET "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir?format=raw" -o curl_ipfs_dir_block_param_output &&
    test_cmp expected curl_ipfs_dir_block_param_output
    '

    test_expect_success "GET for application/vnd.ipld.raw returns a raw block" '
    ipfs block get "/ipfs/$ROOT_DIR_CID/dir" > expected_block &&
    curl -sX GET -H "Accept: application/vnd.ipld.raw" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir" -o curl_ipfs_dir_block_accept_output &&
    test_cmp expected_block curl_ipfs_dir_block_accept_output
    '

# Make sure expected HTTP headers are returned with the block bytes

    test_expect_success "GET response for application/vnd.ipld.raw has expected Content-Type" '
    curl -svX GET -H "Accept: application/vnd.ipld.raw" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir/ascii.txt" >/dev/null 2>curl_output &&
    cat curl_output &&
    grep "< Content-Type: application/vnd.ipld.raw" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes Content-Length" '
    BYTES=$(ipfs block get $FILE_CID | wc --bytes)
    grep "< Content-Length: $BYTES" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes Content-Disposition" '
    grep "< Content-Disposition: attachment\; filename=\"${FILE_CID}.bin\"" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes nosniff hint" '
    grep "< X-Content-Type-Options: nosniff" curl_output
    '

    test_expect_success "GET for application/vnd.ipld.raw with query filename includes Content-Disposition with custom filename" '
    curl -svX GET -H "Accept: application/vnd.ipld.raw" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT_DIR_CID/dir/ascii.txt?filename=foobar.bin" >/dev/null 2>curl_output_filename &&
    cat curl_output_filename &&
    grep "< Content-Disposition: attachment\; filename=\"foobar.bin\"" curl_output_filename
    '

# Cache control HTTP headers
# (basic checks, detailed behavior is tested in  t0116-gateway-cache.sh)

    test_expect_success "GET response for application/vnd.ipld.raw includes Etag" '
    grep "< Etag: \"${FILE_CID}.raw\"" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes X-Ipfs-Path and X-Ipfs-Roots" '
    grep "< X-Ipfs-Path" curl_output &&
    grep "< X-Ipfs-Roots" curl_output
    '

    test_expect_success "GET response for application/vnd.ipld.raw includes Cache-Control" '
    grep "< Cache-Control" curl_output
    '

test_kill_ipfs_daemon

test_done
