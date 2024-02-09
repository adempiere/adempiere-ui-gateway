-- connects to the adempiere database and adempiere schema
\c adempiere adempiere



-- Add App-Registration with S3 Minio
INSERT INTO AD_AppRegistration 
    (AD_AppRegistration_ID,AD_AppSupport_ID,AD_Client_ID,AD_Org_ID,ApplicationType,Created,CreatedBy,Host,IsActive,Name,Port,Timeout,Updated,UpdatedBy,UUID,Value,VersionNo) 
    VALUES (1000006,50012,11,0,'WDV',TO_TIMESTAMP('2024-02-09 11:02:44','YYYY-MM-DD HH24:MI:SS'),100,'http://s3.storage:9000','Y','S3 Minio Storage',0,0,TO_TIMESTAMP('2024-02-09 11:02:44','YYYY-MM-DD HH24:MI:SS'),100,'78669372-61a4-457c-a158-102f0e1008ea','S3-MINIO','1.0')
;

-- Add App-Regitration Parameters values
INSERT INTO AD_AppRegistration_Para 
    (AD_AppRegistration_ID,AD_AppRegistration_Para_ID,AD_AppSupport_Para_ID,AD_Client_ID,AD_Org_ID,Created,CreatedBy,Description,IsActive,ParameterName,ParameterType,ParameterValue,Updated,UpdatedBy,UUID) 
    VALUES (1000006,1000008,50012,11,50001,TO_TIMESTAMP('2024-02-09 11:02:44','YYYY-MM-DD HH24:MI:SS'),100,'Access key provided by S3 storage provider','Y','ACCESS_KEY','C','adempiere',TO_TIMESTAMP('2024-02-09 11:02:44','YYYY-MM-DD HH24:MI:SS'),100,'6e1bab7d-b667-408b-8a6a-f434d8afd5e9')
;
INSERT INTO AD_AppRegistration_Para 
    (AD_AppRegistration_ID,AD_AppRegistration_Para_ID,AD_AppSupport_Para_ID,AD_Client_ID,AD_Org_ID,Created,CreatedBy,Description,IsActive,ParameterName,ParameterType,ParameterValue,Updated,UpdatedBy,UUID) 
    VALUES (1000006,1000009,50013,11,50001,TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'Secret key provided by S3 storage provider','Y','SECRET_KEY','C','adempiere',TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'bcc5dafe-f410-4897-9813-fcda48189a66')
;
INSERT INTO AD_AppRegistration_Para 
    (AD_AppRegistration_ID,AD_AppRegistration_Para_ID,AD_AppSupport_Para_ID,AD_Client_ID,AD_Org_ID,Created,CreatedBy,Description,IsActive,ParameterName,ParameterType,ParameterValue,Updated,UpdatedBy,UUID) 
    VALUES (1000006,1000010,50015,11,50001,TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'Bucket region','Y','BUCKET_REGION','C','adempiere',TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'4716be6a-9b07-458d-a03f-21438c7e80c1')
;
INSERT INTO AD_AppRegistration_Para 
    (AD_AppRegistration_ID,AD_AppRegistration_Para_ID,AD_AppSupport_Para_ID,AD_Client_ID,AD_Org_ID,Created,CreatedBy,Description,IsActive,ParameterName,ParameterType,ParameterValue,Updated,UpdatedBy,UUID) 
    VALUES (1000006,1000011,50016,11,50001,TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'Bucket Name','Y','BUCKET_NAME','C','adempiere',TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'e873f8f5-f6dd-46ff-a176-d050a07ec399')
;
INSERT INTO AD_AppRegistration_Para (AD_AppRegistration_ID,AD_AppRegistration_Para_ID,AD_AppSupport_Para_ID,AD_Client_ID,AD_Org_ID,Created,CreatedBy,Description,IsActive,ParameterName,ParameterType,Updated,UpdatedBy,UUID) VALUES (1000006,1000012,50017,11,50001,TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'Base folder for save files','Y','BaseFolder','C',TO_TIMESTAMP('2024-02-09 11:02:45','YYYY-MM-DD HH24:MI:SS'),100,'d693a29c-f4dd-4807-aed0-979d1714a6fb')
;



-- Set File Hanlder to Client Info
UPDATE AD_ClientInfo SET 
    FileHandler_ID=1000006,
    Updated=TO_TIMESTAMP('2024-02-09 11:03:50','YYYY-MM-DD HH24:MI:SS'),
    UpdatedBy=100 
    WHERE AD_Client_ID=11
;
