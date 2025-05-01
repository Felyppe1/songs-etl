resource "google_workflows_workflow" "songs_etl_workflow" {
    name     = "songs-etl"
    project  = var.project
    region   = var.region

    description = "Workflow for the songs ETL process"

    service_account = google_service_account.service_account.email

    source_contents = <<-EOT
    main:
        params: [input]
        steps:
        - extract:
            call: http.post
            args:
                url: "${google_cloudfunctions2_function.extract_cloud_function.service_config[0].uri}"
                auth:
                    type: OIDC
            result: extract_response
        - logExtractResponse:
            call: sys.log
            args:
                text: "$${extract_response.body}"
        - transform:
            call: http.post
            args:
                url: "${google_cloudfunctions2_function.transform_cloud_function.service_config[0].uri}"
                auth:
                    type: OIDC
            result: transform_response
        - logTransformResponse:
            call: sys.log
            args:
                text: "$${transform_response.body}"
    EOT

    depends_on = [
        google_project_service.required_apis["workflowexecutions.googleapis.com"],
        google_cloudfunctions2_function.extract_cloud_function,
        google_cloudfunctions2_function.transform_cloud_function
    ]
}