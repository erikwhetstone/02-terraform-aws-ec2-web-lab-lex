# check blocks warn but never stop a run. Blocking guardrails live in the
# provider (allowed_account_ids), variable validations, and data-source
# postconditions.

check "http_access_is_narrow" {
  assert {
    condition     = try(tonumber(split("/", var.allowed_http_cidr)[1]) >= 24, false)
    error_message = "allowed_http_cidr is wider than /24. The website is reachable by many more addresses than your own. Use your public IP as a /32 unless wider access is intended."
  }
}

check "expiration_date_is_future" {
  assert {
    condition     = try(timecmp(plantimestamp(), "${var.expiration_date}T23:59:59Z") < 0, false)
    error_message = "expiration_date is in the past or is not a real calendar date. Update it so the ExpiresOn tag stays meaningful."
  }
}
