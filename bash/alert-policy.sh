{
  "displayName": "Alert policy",
  "userLabels": {
    "env": "prod"
  },
  "conditions": [
    {
      "displayName": "New condition",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_disk\" AND metric.type = \"logging.googleapis.com/user/scheduled_snapshot_failure_count\" AND metric.labels.status = \"DONE\"",
        "aggregations": [
          {
            "alignmentPeriod": "600s",
            "crossSeriesReducer": "REDUCE_SUM",
            "perSeriesAligner": "ALIGN_SUM"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "300s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 1
      }
    }
  ],
  "alertStrategy": {
    "notificationPrompts": [
      "OPENED"
    ]
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "projects/scio-internal/notificationChannels/15793665970123050031"
  ],
  "severity": "SEVERITY_UNSPECIFIED"
}