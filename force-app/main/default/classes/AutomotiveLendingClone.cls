public class AutomotiveLendingClone {

    
    
    // Enum Field names
    private static final String DM_APP_FORM_PRODUCT_STAGE_FIELD_NAME = 'ApplicationFormProductStage';
    private static final String DM_APP_FORM_STAGE_FIELD_NAME = 'ApplicationFormStage';
    private static final String DM_APPLICANT_STATUS_FIELD_NAME = 'ApplicantVisibleStatus';
    private static final String DM_PARTNER_STATUS_FIELD_NAME = 'PartnerVisibleStatus';
    
    // Decission Matrix Names
    private static final String DM_AFP_STAGE_TO_AF_STAGE = 'AFPStage_To_AFStage';
    private static final String DM_AFP_Stage_To_AVS_PVS = 'AFPStage_To_AVS_PVS';
    //private static final String DM_AFP_Stage_To_AVS_PVS = 'AFPStage_To_AVS_PVS_TEMP';
    private static final String DM_AUTO_LOAN_CDS = 'Automotive_Lending_CDS_Config';
    
    // Decission Matrix input and output fields
    private static final String DM_UW_ACCESS_FIELD_NAME = 'Underwriter_Access';
    private static final String DM_APPLICANT_AGENT_ACCESS_FIELD_NAME = 'Applicant_Agent_Access';
    private static final String DM_APPLICANT_DEALER_ACCESS_FIELD_NAME = 'Dealer_Access';

    // CDS Enabled Entity names
    private static final String APPLICATION_FORM = 'ApplicationForm';
    private static final String APPLICATION_FORM_PRODUCT = 'ApplicationFormProduct';
    private static final String PARTY_PROFILE = 'PartyProfile';

    // Participant group names
    private static final String UNDERWRITER_PARTICIPANT_GROUP_NAME = 'Underwriter_Group';
    private static final String AGENT_PARTICIPANT_GROUP_NAME = 'Agent_Group';
    
    // CDS user permision set
    //private static final String AUTOLENDING_UW_PERMISSION_SET_NAME = 'VehicleandAssetLendingUWUser';
    private static final String AUTOLENDING_PARTNER_PERMISSION_SET_NAME = 'VehicleAndAssetLendingPartnerUser';
    //private static final String AUTOLENDING_AGENT_PERMISSION_SET_NAME = 'VehAndAssetLendingForAgentsUser';
    private static final String AUTOLENDING_CUSTOMER_PERMISSION_SET_NAME = 'VehicleAndAssetLendingCustomerUser';
    
    
    /**
     *  Automotive_Lending_CDS_Config 
     * AFPStage_To_AVS_PVS
     * AFPStage_To_AFStage
     * 
     * Applicant_Agent_Access=ApplicationFormRead,ApplicationFormProductRead,PartyProfileRead, 
     * Dealer_Access=ApplicationFormRead,ApplicationFormProductRead,PartyProfileRead, 
     * Underwriter_Access=ApplicationFormRW,ApplicationFormProductRW,
    */
        
    static {
        CDSCacheHelper.loadCDSData();
    }


    public void execute() {

        try {

          ID applicationFormProductId = '13ZWs0000006H7pMAE';

            ApplicationFormProduct appFormProduct = [SELECT Id, Stage, ApplicantVisibleStatus, ApplicationFormId FROM ApplicationFormProduct WHERE Id =: applicationFormProductId];

            updateApplicantAndPartnerVisibleStatus(appFormProduct);
            updateApplicationFormStage(appFormProduct);

            
            Invocable.Action.Result cdsDmResult = invokeDecisionMatrix(DM_AUTO_LOAN_CDS, appFormProduct.Stage);
            String applicantAgentRole = getOutputVal(cdsDmResult, DM_APPLICANT_AGENT_ACCESS_FIELD_NAME);
            String underwriterRole = getOutputVal(cdsDmResult, DM_UW_ACCESS_FIELD_NAME);
            String dealerRole = getOutputVal(cdsDmResult, DM_APPLICANT_DEALER_ACCESS_FIELD_NAME);

             
            String[] applicantAgentRoles = applicantAgentRole.split(',');
            String[] underwriterRoles = underwriterRole.split(',');
            String[] dealerRoles = dealerRole.split(',');
            
            Set <Id> partyProfileIds = new Set < Id > ();

            List <Applicant> applicants = [SELECT Id, Email, ApplicationFormId, PartyProfileId FROM Applicant WHERE ApplicationFormId =: appFormProduct.ApplicationFormId];

            System.debug('P1');
            // Extending/Modifying sharing Customer users
            for (Applicant applicant: applicants) {
                if (applicant.PartyProfileId != null) {
                    partyProfileIds.add(applicant.PartyProfileId);
                }
                 
                // If no users where email matches applicant email, continue
                List<User> users = [SELECT Id FROM USER WHERE Email =: applicant.Email];
                if (users.size() == 0) {
                    continue;
                }
                System.debug('P2');
                User user = users.get(0);

                // If customer user does not have CDS permission, continue
                if (!hasValidCDSUserPermission(user.Id, AUTOLENDING_CUSTOMER_PERMISSION_SET_NAME)) {
                    continue;
                }

                System.debug('P3');
                for (String cdsRole: applicantAgentRoles) {
                    if (cdsRole.startsWith(APPLICATION_FORM_PRODUCT)) {
                        System.debug('P31');
                        handleApplicationFormProductParticipants(user.Id, appFormProduct, cdsRole);
                    } else if (cdsRole.startsWith(APPLICATION_FORM)) {
                        System.debug('P32');
                        handleApplicationFormParticipants(user.Id, appFormProduct, cdsRole);
                    } else if (cdsRole.startsWith(PARTY_PROFILE)) {
                        System.debug('P33');
                        handlePartyProfileParticipants(user.Id, applicant.PartyProfileId, cdsRole);
                    }
                }
            } 
            System.debug('P4');
            // Updating / Creating Participant Records for Underwrite groups 
            handleCDSUpdatesForGroups(UNDERWRITER_PARTICIPANT_GROUP_NAME, underwriterRoles, 
                                      partyProfileIds, appFormProduct);

            System.debug('P5');
            // Updating / Creating Participant Records for Agent groups 
            handleCDSUpdatesForGroups(AGENT_PARTICIPANT_GROUP_NAME, applicantAgentRoles, 
                                      partyProfileIds, appFormProduct);
            System.debug('P5');
            // Updating / Creating Participant Records Dealer/Partners 
            handleCDSUpdatesForDealers(dealerRoles, partyProfileIds, appFormProduct, AUTOLENDING_PARTNER_PERMISSION_SET_NAME);
            


        } catch (Exception ex) {

            System.debug(ex);
        }



    }

    public static boolean hasValidCDSUserPermission(Id userId, String permissionSetName) {
        // If user does not have CDS permission, continue
        List<PermissionSetAssignment> permissionSetAssignments = [SELECT AssigneeId, PermissionSet.Name FROM PermissionSetAssignment 
                                                                  WHERE AssigneeId =: userId AND PermissionSet.Name =: permissionSetName ];
        return (permissionSetAssignments.size() > 0);      
    }

    public static void handleCDSUpdatesForGroups(String groupName, String[] roles, 
                                                 Set < Id > partyProfileIds, ApplicationFormProduct appFormProduct) {
        String groupId = CDSCacheHelper.PARTICIPANT_GROUP_NAME_TO_ID.get(groupName);
        for (String cdsRole: roles) {
            if (cdsRole.startsWith(APPLICATION_FORM_PRODUCT)) {
                handleApplicationFormProductParticipants(groupId, appFormProduct, cdsRole);
            } else if (cdsRole.startsWith(APPLICATION_FORM)) {
                handleApplicationFormParticipants(groupId, appFormProduct, cdsRole);
            } else if (cdsRole.startsWith(PARTY_PROFILE)) {
                for (Id partyProfileId: partyProfileIds) {
                    handlePartyProfileParticipants(groupId, partyProfileId, cdsRole);
                }
            }
        }
    }

    public static void updateApplicantAndPartnerVisibleStatus(ApplicationFormProduct appFormProduct) {
        Invocable.Action.Result result = invokeDecisionMatrix(DM_AFP_Stage_To_AVS_PVS, appFormProduct.Stage);
        String applicantVisibleStatus = getOutputVal(result, DM_APPLICANT_STATUS_FIELD_NAME);
        String partnerVisibleStatus = getOutputVal(result, DM_PARTNER_STATUS_FIELD_NAME);
        appFormProduct.ApplicantVisibleStatus = applicantVisibleStatus;
        appFormProduct.PartnerVisibleStatus = partnerVisibleStatus;
        upsert appFormProduct;
    }

    public static void updateApplicationFormStage(ApplicationFormProduct appFormProduct) {
        Invocable.Action.Result result = invokeDecisionMatrix(DM_AFP_STAGE_TO_AF_STAGE, appFormProduct.Stage);
        String applicationFormStage = getOutputVal(result, DM_APP_FORM_STAGE_FIELD_NAME);
        
        ApplicationForm applicationForm = new ApplicationForm();
        applicationForm.Id = appFormProduct.ApplicationFormId;
        applicationForm.Stage = applicationFormStage;
        upsert applicationForm;
    }

    public static void handleCDSUpdatesForDealers(String[] dealerRoles, Set < Id > partyProfileIds, 
                                                  ApplicationFormProduct appFormProduct, String requiredPermSet) {
        
        List <ApplicationFormSellerItem> sellerItems = [SELECT Id, SellerId FROM ApplicationFormSellerItem WHERE ApplicationFormProductId =: appFormProduct.Id];
        //Return if there are no seller items
        if (sellerItems.size() == 0) {
            system.debug('No seller items found');
            return;
        } else {
            ApplicationFormSellerItem sellerItem = sellerItems.get(0);
            List<User> users = [SELECT Id FROM USER WHERE AccountId =: sellerItem.SellerId];
            // Return if Account on the dealer is not a valid user      
            if (users.size() == 0) {
                system.debug('No users items found');
              return;
            }
            Id dealerUserId = users.get(0).Id;
            if (!hasValidCDSUserPermission(dealerUserId, requiredPermSet)) {
                    return;
             }
            /////////
            for (String cdsRole: dealerRoles) {
              if (cdsRole.startsWith(APPLICATION_FORM_PRODUCT)) {
                 handleApplicationFormProductParticipants(dealerUserId, appFormProduct, cdsRole);
              } else if (cdsRole.startsWith(APPLICATION_FORM)) {
                 handleApplicationFormParticipants(dealerUserId, appFormProduct, cdsRole);
              } else if (cdsRole.startsWith(PARTY_PROFILE)) {
                 for (Id partyProfileId: partyProfileIds) {
                    handlePartyProfileParticipants(dealerUserId, partyProfileId, cdsRole);
                 }
              }
          }
        }
    }
    
    public static void handleApplicationFormParticipants(Id userOrGroupId, ApplicationFormProduct appFormProduct, String roleName) {
        List<ApplicationFormParticipant> appFormParticipants = [SELECT Id, ParticipantRoleId FROM ApplicationFormParticipant WHERE ParticipantId =: userOrGroupId AND ApplicationFormId=:appFormProduct.ApplicationFormId];
        String roleId = CDSCacheHelper.PARTICIPANT_ROLE_NAME_TO_ID.get(roleName);
        if (appFormParticipants.size() == 0) {
            ApplicationFormParticipant participant = new ApplicationFormParticipant(ApplicationFormId = appFormProduct.ApplicationFormId,
                                                                                    IsActive = true,
                                                                                    ParticipantRoleId = roleId,
                                                                                    ParticipantId=userOrGroupId);
            insert participant;
        } else {
            ApplicationFormParticipant participant = appFormParticipants.get(0);
            participant.IsActive = true;
            participant.ParticipantRoleId = roleId;
            upsert participant;
        }
    }

    public static void handleApplicationFormProductParticipants(Id userOrGroupId, ApplicationFormProduct appFormProduct, String roleName) {
        List<AppFormProductParticipant> participants = [SELECT Id, ParticipantRoleId FROM AppFormProductParticipant WHERE ParticipantId =: userOrGroupId AND ApplicationFormProductId=:appFormProduct.Id];
        String roleId = CDSCacheHelper.PARTICIPANT_ROLE_NAME_TO_ID.get(roleName);
        if (participants.size() == 0) {
            AppFormProductParticipant participant = new AppFormProductParticipant(ApplicationFormProductId = appFormProduct.Id,
                                                                                  IsActive = true,
                                                                                  ParticipantRoleId = roleId,
                                                                                  ParticipantId=userOrGroupId);
            insert participant;
        } else {
            AppFormProductParticipant participant = participants.get(0);
            participant.IsActive = true;
            participant.ParticipantRoleId = roleId;
            upsert participant;
        }
    }

    public static void handlePartyProfileParticipants(Id userOrGroupId, String partyProfileId, String roleName) {
        List<PartyProfileParticipant> participants = [SELECT Id, ParticipantRoleId FROM PartyProfileParticipant WHERE ParticipantId =: userOrGroupId AND PartyProfileId=:partyProfileId];
        String roleId = CDSCacheHelper.PARTICIPANT_ROLE_NAME_TO_ID.get(roleName);
        if (participants.size() == 0) {
            PartyProfileParticipant participant = new PartyProfileParticipant(PartyProfileId = partyProfileId,
                                                                              IsActive = true,
                                                                              ParticipantRoleId = roleId,
                                                                              ParticipantId=userOrGroupId);
            insert participant;
        } else {
            PartyProfileParticipant participant = participants.get(0);
            participant.IsActive = true;
            participant.ParticipantRoleId = roleId;
            upsert participant;
        }
    }


    public static Invocable.Action.Result invokeDecisionMatrix(String decisionMatrixName, String appFormProductStageVal) {
        // Create an Invocable.Action
        Invocable.Action action = Invocable.Action.createCustomAction('runDecisionMatrix', decisionMatrixName);
        action.setInvocationParameter(DM_APP_FORM_PRODUCT_STAGE_FIELD_NAME, appFormProductStageVal);
        List < Invocable.Action.Result > results = action.invoke();
        return results.get(0);
    }

    public static String getOutputVal(Invocable.Action.Result result, String outputFieldName) {
        return (String) result.getOutputParameters().get(outputFieldName);
    }


    public class Result {
        @InvocableVariable(label = 'Message'
                           description = 'Resulted output of the action.'
                           required = true)
        public String message;
        
        @InvocableVariable(label = 'Status'
                           description = 'Resulted status of the action.'
                           required = true)
        public boolean isSuccess;
    }
}