#!/bin/sh

export HTTP_COOKIE="user_id=abc123"
export QUERY_STRING=$2
export REQUEST_METHOD="GET"

./$1 $2 


