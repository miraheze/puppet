# SPDX-License-Identifier: Apache-2.0
# @summary manage the log rotate service
# @param hourly By default logrotate runs daily via a systemd timer, if true it runs hourly instead
class logrotate (
    Boolean $hourly = false,
) {
    stdlib::ensure_packages('logrotate')
    $hourly_content = @(CONTENT)
