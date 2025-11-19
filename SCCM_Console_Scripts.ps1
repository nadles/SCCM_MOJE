Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}" # Hardware Inventory
Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}" # Machine Policy Assignments Request
Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}" # Machine Policy Evaluation
Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000113}" # Scan by Update Source
Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000108}" # Software Updates Assignments Evaluation Cycle
