#!/bin/bash
ruby -wS test_document_parser.rb 2>&1 | grep -v "warning: setting Encoding.default_..ternal"
exit