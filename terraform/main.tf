provider "google" {
  project = var.project
  region  = "us-central1"
  zone    = "us-central1-f"
}

resource "google_sql_database_instance" "master" {
  name             = "emoji-alert-instance"
  database_version = "POSTGRES_11"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "database" {
  name      = "emoji-alert"
  instance  = google_sql_database_instance.master.name
}

resource "google_sql_user" "user" {
  name      = "postgres"
  instance  = google_sql_database_instance.master.name
  password  = var.db_pass
}

resource "google_storage_bucket" "bucket" {
  name = var.bucket_name
}

resource "google_storage_bucket_object" "archive" {
  name   = "emoji_alert.zip"
  bucket = google_storage_bucket.bucket.name
  source = "../emoji_alert.zip"
}

resource "google_service_account" "service_account" {
  account_id   = "emoji-alert"
  display_name = "Emoji Alert"
}

resource "google_project_iam_member" "db_client" {
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_cloudfunctions_function" "function" {
  name        = "emoji-alert"
  description = "😍"
  runtime     = "python37"

  available_memory_mb   = 256
  trigger_http          = true
  entry_point           = "main"
  ingress_settings      = "ALLOW_ALL"
  max_instances         = 1
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name

  service_account_email = google_service_account.service_account.email

  environment_variables = {
    CONNECTION_NAME = google_sql_database_instance.master.connection_name
    PG_USER         = google_sql_user.user.name
    PG_PASS         = google_sql_user.user.password
    DB_NAME         = google_sql_database.database.name
    SLACK_KEY       = var.slack_key
    SENDGRID_KEY    = var.sendgrid_key
  }
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_cloud_scheduler_job" "job" {
  name             = "emoji-alert"
  description      = "😍"
  schedule         = "*/20 * * * *"
  time_zone        = "America/New_York"
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions_function.function.https_trigger_url
    body        = base64encode(
<<EOF
{
"in_cloud": true,
"to_email": "${var.to_email}",
"from_email": "${var.from_email}"
}
EOF
)
    oidc_token {
      service_account_email = google_service_account.service_account.email
    }
  }
}

