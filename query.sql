SELECT   
  SYS.Name0 AS ComputerName,
  SYS.ResourceID,CIR.fromCIID,
  UI.Title AS UpdateTitle,
  CASE UCS.Status
  WHEN 2 THEN 'Missing'
  WHEN 3 THEN 'Installed'
  ELSE 'Other'
  END AS UpdateStatus,
  UCS.LastStatusCheckTime AS LastStatusCheckTime
  FROM
  v_R_System SYS
  JOIN
  v_FullCollectionMembership FCM ON SYS.ResourceID = FCM.ResourceID
  JOIN
  v_UpdateComplianceStatus UCS ON SYS.ResourceID = UCS.ResourceID
  JOIN
  v_CIRelation CIR ON UCS.CI_ID = CIR.TOCIID
  JOIN
  v_UpdateInfo UI ON CIR.TOCIID = UI.CI_ID
  WHERE
  FCM.CollectionID = 'ID_KOLEKCJI'
  AND CIR.RelationType = 1
