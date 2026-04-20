public class PORTERS_DTO_CandidateResponse {
    public Integer totalCount {get;set;}
    public List<Wrapper> result {get;set;}

    public class Wrapper {
        public String personId {get;set;}
        public String personName {get;set;}
        public String telephone{get;set;}
        public String mail{get;set;}
        public String mobile{get;set;}
        public String mobileMail{get;set;}
        public String registrationDate{get;set;}
        public String registeredBy{get;set;}
        public String updateDate{get;set;}
        public String updatedBy{get;set;}
    }
    public IF_pts_Can__c convertToIF(Wrapper wrapper) {
        IF_pts_Can__c pc = new IF_pts_Can__c ();
        
        if(wrapper.personId <> null)pc.IndividualContactId__c = wrapper.personId ;
        if(wrapper.personName <> null)pc.IndividualName__c = wrapper.personName;
        if(wrapper.telephone<> null)pc.IndividualPhone__c = wrapper.telephone;
        if(wrapper.mail<> null)pc.IndividualEmail__c = wrapper.mail;
        if(wrapper.mobile<> null)pc.IndividualMobilePhone__c = wrapper.mobile;
        if(wrapper.mobileMail<> null)pc.IndividualMobileEmail__c = wrapper.mobileMail;
        if(wrapper.registrationDate<> null)pc.CreatedDate__c = wrapper.registrationDate;
        if(wrapper.registeredBy<> null)pc.CreatedBy__c = wrapper.registeredBy;
        if(wrapper.updateDate<> null)pc.LastModifiedDate__c = wrapper.updateDate;
        if(wrapper.updatedBy<> null)pc.LastModifiedBy__c = wrapper.updatedBy;

        return pc;
    }
}