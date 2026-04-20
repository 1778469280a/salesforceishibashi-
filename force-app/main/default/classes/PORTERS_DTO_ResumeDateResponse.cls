public class PORTERS_DTO_ResumeDateResponse {
    public Integer totalCount {get;set;}
    public List<Wrapper> result {get;set;}
    
    // フィールドマッピング：PORTERS API 項目名 → Salesforce 項目 API 名
    private static final Map<String, String> FIELD_MAPPING = new Map<String, String>{
        'Resume.P_RegisterChannel'               => 'RegistrationSource__c',
        'Resume.U_4519E06428F3E45FB1C14E878185BE' => 'RegistrationMethod__c',
        'Resume.U_45A05CBAF79D5527F38A6F59E1243B' => 'ScoutStaffInCharge__c',
        'Resume.U_E49E1480A206956CDD882F6A2063E7' => 'JobOfferReportingSite__c',
        'Resume.P_Id'                             => 'ResumeId__c',
        'Resume.U_AC5A0D55E86D3363238C61F123390E' => 'MailMagazineStatus__c',
        'Resume.U_LASTLOGIN'                      => 'LastLoginDate__c',
        'Resume.U_91DBD8B96BAAD6B33B538CF2494377' => 'FullNameKana__c',
        //'Resume.P_Candidate'                      => 'FullName__c',
        'Resume.P_Candidate'                      => 'IndividualContactID__c',
        'Resume.P_Name'                           => 'CandidateName__c',
        'Resume.P_DateOfBirth'                    => 'BirthDateAndAge__c',
        'Resume.P_Gender'                         => 'Gender__c',
        'Resume.U_4F79E5889587A2E73847A8B269B808' => 'PostalCode__c',
        'Resume.U_7F3DF7F61EEF0679AA432646777832' => 'Prefecture__c',
        'Resume.U_5247D11C2262F3D9D357DA3D7D472B' => 'CurrentAddress__c',
        'Resume.P_Phase'                          => 'LatestPhase__c',
        'Resume.P_PhaseDate'                      => 'LatestPhaseDate__c',
        'Resume.U_673275A4DA445C9B23AC18BDD7C4DC' => 'FinalEducationLevel__c',
        'Resume.U_85DEA8FA18EF17830FD8A036EC95A4' => 'SchoolFacultyDepartment__c',
        'Resume.P_Education'                      => 'EducationDetail__c',
        'Resume.U_217F6B518AF9B5910F86DE3553210E' => 'DeviationValue__c',
        'Resume.P_TelephoneReference'             => 'IndividualPhone__c',
        'Resume.P_MobileReference'                => 'IndividualMobilePhone__c',
        'Resume.P_Mail'                           => 'IndividualEmail__c',
        'Resume.P_MobileMail'                     => 'IndividualMobileEmail__c',
        'Resume.U_57CF0FC339534D5E1CCAB9E5720732' => 'ContactPreference__c',
        'Resume.U_40A13BD8D79CFAA685ED4C454030D3' => 'CurrentEmployer__c',
        'Resume.P_CurrentStatus'                  => 'EmploymentStatus__c',
        'Resume.P_ChangeJobsCount'                => 'NumberOfCompaniesWorked__c',
        'Resume.U_97A8BC60EE4C6181D71B62B0A94867' => 'PreviousContactInfoAndName__c',
        'Resume.U_C5A71273732B694582E953EE29B262' => 'HousingCategory__c',
        'Resume.U_48B3606404C39777B9C4D652EB9B33' => 'Birthplace__c',
        'Resume.U_983513B1B1284C1AE08155656440DE' => 'HasSpouse__c',
        'Resume.U_7790CB5A294982B42C78415C082D80' => 'FamilyStructure__c',
        'Resume.U_459C918AD0E71B7D760A7B466FEC2D' => 'JobChangeCount__c',
        'Resume.U_5598122582348E10065B3A9B2FCC79' => 'Interviewer__c',
        'Resume.U_7C79BBCF39E0D849E54929A8D70B06' => 'InboundSalesStaff__c',
        'Resume.U_AEEC844BBC2B3D25C87D589DDCDC28' => 'ClosingSalesStaff__c',
        'Resume.U_223D0173F7AB1E5F4A15DC0DB0904C' => 'RecommendationLetter__c',
        'Resume.U_BC07D210E9789C7E4C16092C2718F0' => 'OverallEvaluation__c',
        'Resume.U_959F4DF5330A30BF416EE53592D689' => 'OverallEvaluationMemo__c',
        'Resume.U_DF0E1BF1E942DE5B44759F145F26CC' => 'UrgencyLevel__c',
        'Resume.U_A1D41116DCC9F246FBE2505927D801' => 'UrgencyMemo__c',
        'Resume.U_1342FD85C7DD1612C466A201748F45' => 'ResignationReason__c',
        'Resume.U_AA13AA68D5EF4EAC7F9E80626F6401' => 'ResignationReasonMemo__c',
        'Resume.U_7A82F71961342ABC309E82F3CB4549' => 'InterviewDate__c',
        'Resume.U_088F183F5A467370986D82D8A56820' => 'InterviewType__c',
        'Resume.U_84014DC41521C8B72456DA0602B1DC' => 'TalentListComment__c',
        'Resume.U_6BFFD96228CF84803A26F4F04200F0' => 'CommunicationSkill__c',
        'Resume.U_D430BFCB51DF105C5546258FA6D8E2' => 'CommunicationMemo__c',
        'Resume.U_DDA38E8BC45B94D70819747CE7B627' => 'PreferredCompanySize__c',
        'Resume.U_60E42092BAB538A1E256CE86B3418A' => 'CompanySizeMemo__c',
        'Resume.U_96F0A72569A21441DA7E5F9D6ACBEA' => 'ReferralInternalStaff__c',
        'Resume.U_F2C3465D66ECA0A6227F731DB868B0' => 'ReferralManagementMemo__c',
        'Resume.U_AGENTSTATUS'                    => 'AgentUsageStatus__c',
        'Resume.U_AGETNTSUSAGE'                   => 'CurrentUsingAgents__c',
        'Resume.U_4495E00E8A888DDC61CF3A56D104F8' => 'OtherAgentApplicationStatus__c',
        'Resume.P_ExpectArea'                     => 'PreferredWorkLocation__c',
        'Resume.U_80F76B1B3D339C9387773F1C457E51' => 'PrimaryWorkLocation__c',
        'Resume.U_KKSKGN'                         => 'PreferredWorkCity__c',
        'Resume.U_CE0C8801E69FA2E26E349B09856C0C' => 'WillingToRelocate__c',
        'Resume.P_ExpectEmploymentType'           => 'PreferredEmploymentType__c',
        'Resume.U_94A609C4275F50CC7C617F6CE0A409' => 'PreferredChangeTime__c',
        'Resume.P_ExpectCondition'                => 'PreferredConditionsDetail__c',
        'Resume.U_F7E834098FD85B1A86E77396219E2B' => 'Holidays__c',
        'Resume.U_EF980BC1829E8EC05C300033CFABFC' => 'HolidayMemo__c',
        'Resume.P_ExperiencedIndustry'            => 'ExperiencedIndustries__c',
        'Resume.P_ExperiencedJobCategory'         => 'ExperiencedOccupationsCategory__c',
        'Resume.P_CurrentSalary'                  => 'CurrentAnnualIncome__c',
        'Resume.U_7A6877EFE8D7FB90A4DA9571370642' => 'CurrentMonthlyIncome__c',
        'Resume.U_D16C6D4F1B6C32B4AC53819D88043F' => 'PreferredAnnualIncome__c',
        'Resume.U_8D0C259C0AFF6CDF1806A87DC5F439' => 'MinimumAnnualIncome__c',
        'Resume.U_C4E94650CDEFC413E234DD7E6C9274' => 'IncomeMemo__c',
        'Resume.U_971466A5917927863462EF570C1169' => 'IsCarCommuting__c',
        'Resume.U_8F8E666EE51CC8D00788940A3DC98C' => 'CarCommutingDetail__c',
        'Resume.P_ExpectIndustry'                 => 'PreferredIndustries__c',
        'Resume.P_ExpectJobCategory'              => 'PreferredOccupations__c',
        'Resume.P_CarrierSummary'                 => 'WorkHistoryDetail__c',
        'Resume.U_42902DED368132819B152E589AA578' => 'WorkHistoryDetailBackup__c',
        'Resume.U_5475007220C4E3258472D5626A0563' => 'SelfPromotion__c',
        'Resume.U_C80486912236BD021D1B63FFB762B4' => 'LicensesAndCertifications__c',
        'Resume.U_12A4C297CC5D159213875DA2210BF2' => 'SkillsAndCertificationsMemo__c',
        'Resume.U_ADE568278037E18C20F3AF78AAF8A8' => 'OtherLanguagesAndRemarks__c',
        'Resume.U_90AD127E5FCEBCD1AF01DDC8295708' => 'EnglishSkill__c',
        'Resume.U_F205EBF7F6A862C6A9E8DDB135F797' => 'ToeflScore__c',
        'Resume.U_94E831023512892988CDD4FC4987EB' => 'ToeicScore__c',
        'Resume.U_13C45F7FFAFC1AB430E6038C76125A' => 'EntryAdditionalInfo__c',
        'Resume.U_5F7FC5144BA471117A376B60BC8D90' => 'MyPageOtherRequests__c',
        'Resume.U_8E20986D8967D107BEE5D63870AD68' => 'MyPageUTurnMeetingDate__c',
        'Resume.U_DDF5A119155AD1F559BAA37C031C4E' => 'InquirySource__c',
        'Resume.P_RegistrationDate'               => 'CreatedDate__c',
        'Resume.P_RegisteredBy'                   => 'CreatedBy__c',
        'Resume.P_UpdateDate'                     => 'LastModifiedDate__c',
        'Resume.P_UpdatedBy'                      => 'LastModifiedBy__c',
        'Resume.U_GCLID'                          => 'Gclid__c',
        'Resume.U_B41102CD1A612DA93AA74B5462DE6E' => 'BillableSite1__c',
        'Resume.U_8B5178364C17E24A72A2113296D4A5' => 'BillingDate1__c',
        'Resume.U_9B5DE90D67C3C57A12D66F84AFA05F' => 'BillableSite2__c',
        'Resume.U_ACB4CAC6E89348FD55DF19E6E20155' => 'BillingDate2__c',
        'Resume.U_8EF0F79E169EAD365B63D86C9C80B8' => 'BillingExclusionMemo__c'
    };
    public class Wrapper {
        public Map<String, String> data {get;set;}
    }
    public IF_pts_resume__c convertToIF(Wrapper w) {
        IF_pts_resume__c rec = new IF_pts_resume__c();
        rec.IF_pts_CanId__c = null;
        if(w == null || w.data == null) return rec;
    
        Map<String, Schema.SObjectField> fieldMap =
            IF_pts_resume__c.SObjectType.getDescribe().fields.getMap();
    
        for(String sourceKey : w.data.keySet()){
    
            if(!FIELD_MAPPING.containsKey(sourceKey)) continue;
    
            String targetField = FIELD_MAPPING.get(sourceKey);
            String value = w.data.get(sourceKey);
    
            if(String.isBlank(value)) continue;
    
            try{
                Schema.DescribeFieldResult fDesc = fieldMap.get(targetField).getDescribe();
                Schema.DisplayType fType = fDesc.getType();
    
                Object finalValue;
    
                if(fType == Schema.DisplayType.Date){
                    finalValue = Date.valueOf(value);
    
                }else if(fType == Schema.DisplayType.DateTime){
                    finalValue = Datetime.valueOf(value);
    
                }else if(fType == Schema.DisplayType.Integer){
                    finalValue = Integer.valueOf(value);
    
                }else if(fType == Schema.DisplayType.Double
                      || fType == Schema.DisplayType.Currency
                      || fType == Schema.DisplayType.Percent){
                    finalValue = Decimal.valueOf(value);
    
                }else{
                    finalValue = value;
                }
    
                rec.put(targetField, finalValue);
    
            }catch(Exception e){
                System.debug(targetField + ' value=' + value);
            }
        }
    
        return rec;
    }
}