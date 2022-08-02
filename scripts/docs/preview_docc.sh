#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Metrics open source project
##
## Copyright (c) 2018-2019 Apple Inc. and the Swift Metrics project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift Metrics project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

xcrun swift package --disable-sandbox preview-documentation --target $1
