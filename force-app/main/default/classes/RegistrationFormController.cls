public without sharing class RegistrationFormController {
    private static final String RT_NAME = '求職者';
    private static final String PROFILE_NAME = '求職者';
    private static RecordType jobSeekerRecordType;
    private static Profile jobSeekerProfile;

    @AuraEnabled
    public static Id saveRegistration(Map<String, Object> accountData) {
        if (accountData == null) throw new AuraHandledException('登録データがありません。');
        if (jobSeekerRecordType == null) {
            jobSeekerRecordType = [SELECT Id FROM RecordType WHERE Name = :RT_NAME AND SobjectType = 'Account' LIMIT 1];
            if (jobSeekerRecordType == null) throw new AuraHandledException('RecordType "' + RT_NAME + '" が見つかりません。');
        }
        if (jobSeekerProfile == null) {
            jobSeekerProfile = [SELECT Id FROM Profile WHERE Name = :PROFILE_NAME LIMIT 1];
            if (jobSeekerProfile == null) throw new AuraHandledException('Profile "' + PROFILE_NAME + '" が見つかりません。');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Account acc = buildAccount(accountData);
            insert acc;
            if (acc.PersonContactId == null) {
                acc = [SELECT Id, PersonContactId FROM Account WHERE Id = :acc.Id];
                if (acc.PersonContactId == null) {
                    throw new AuraHandledException('Person Account の作成に失敗しました。取引先責任者が生成されませんでした。');
                }
            }

            User newUser = buildUser(accountData, acc.PersonContactId);
            System.debug('ユーザー作成前');
            String createUserResult = Site.createExternalUser(newUser, acc.Id, (String)accountData.get('password'));
            System.debug('ユーザー作成後');
            System.debug(createUserResult);
            // insert newUser;
            return acc.Id;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('登録に失敗しました: ' + e.getMessage());
        }
    }

    private static Account buildAccount(Map<String, Object> data) {
        Account acc = new Account(RecordTypeId = jobSeekerRecordType.Id);
        setIfNotBlank(acc, 'LastName', data.get('lastName'));
        setIfNotBlank(acc, 'FirstName', data.get('firstName'));
        setIfNotBlank(acc, 'PersonEmail', data.get('email'));
        setDateIfValid(acc, 'PersonBirthdate', (String)data.get('birthDate'));
        setIfNotBlank(acc, 'PersonMobilePhone', data.get('phone'));
        acc.NameKanaSei__pc = (String)data.get('lastNameKana');
        acc.NameKanaMei__pc = (String)data.get('firstNameKana');
        acc.Gender__pc = (String)data.get('gender');
        acc.PostalCode1__c = (String)data.get('zipcode');
        acc.City__c = (String)data.get('prefecture');
        acc.CityAndAddress__c = (String)data.get('cityAddress');
        acc.PreferredChangeDate__c = (String)data.get('desiredDate');
        acc.PreferredWorkLocation1__c = (String)data.get('location1');
        acc.PreferredWorkLocation2__c = (String)data.get('location2');
        acc.PreferredWorkLocation3__c = (String)data.get('location3');
        acc.PreferredSalary__c = (String)data.get('selectedSalary');
        acc.CandidateSelectedOccupation__c = (String)data.get('selectedCategories');
        acc.FinalEducationLevel__pc = (String)data.get('selectedEducation');
        acc.SchoolFacultyDepartment__c = (String)data.get('schoolDetail');
        acc.EmploymentStatus__pc = (String)data.get('employmentStatus');
        acc.IsWillingToRelocate__pc = (String)(data.get('transfer'));
        acc.NumberOfCompaniesWorked__c = parseCompanyCount(data.get('companyCount'));
        acc.EmployerName1__c = (String)data.get('companyName');
        if (acc.EmployerName1__c != null) {
            acc.WorkStartDate1__c = parseYearMonth((String)data.get('startDate'));
            acc.WorkEndDate1__c = parseYearMonth((String)data.get('endDate'));
            acc.CurrentAnnualIncome1__c = (String)data.get('currentSalary');
            acc.JobDescription1__pc = (String)data.get('jobDescription');
            acc.Occupation1__c = (String)data.get('selectedExperienceCategories');
            acc.Occupation1Category__c = (String)data.get('selectedExperienceOptions');
        }
        return acc;
    }

    private static void setIfNotBlank(SObject obj, String fieldName, Object value) {
        if (value instanceof String && String.isNotBlank((String)value)) {
            obj.put(fieldName, value);
        }
    }

    private static void setDateIfValid(SObject obj, String fieldName, String dateStr) {
        if (String.isNotBlank(dateStr)) {
            try {
                obj.put(fieldName, Date.valueOf(dateStr));
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Invalid date format: ' + dateStr);
            }
        }
    }

    private static Boolean parseTransfer(Object transfer) {
        return !'不可'.equals(transfer);
    }

    private static Integer parseCompanyCount(Object companyCountObj) {
        String companyCountStr = (String)companyCountObj;
        if (String.isBlank(companyCountStr)) return 0;
        if ('10社以上'.equals(companyCountStr)) return 10;
        String numPart = companyCountStr.replaceAll('[^0-9]', '');
        return String.isNotBlank(numPart) ? Integer.valueOf(numPart) : 0;
    }

    private static Date parseYearMonth(String yearMonth) {
        if (String.isBlank(yearMonth)) return null;
        List<String> parts = yearMonth.split('-');
        if (parts.size() != 2) return null;
        try {
            return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 1);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Invalid year-month format: ' + yearMonth);
            return null;
        }
    }

    private static User buildUser(Map<String, Object> data, Id contactId) {
        String email = (String)data.get('email');
        if (String.isBlank(email)) throw new AuraHandledException('メールアドレスが未設定です。');
        String lastName = (String)data.get('lastName');
        String firstName = (String)data.get('firstName');
        String username = email + '.hurex';
        String localPart = email.substringBefore('@');
        Date today = Date.today();
        String datePart = String.valueOf(today.year()).substring(2)
                        + String.valueOf(today.month()).leftPad(2, '0')
                        + String.valueOf(today.day()).leftPad(2, '0');
        String nickname = localPart + datePart;
        String alias = (lastName != null ? lastName : '') + (firstName != null ? firstName : '');
        if (alias.length() > 8) alias = alias.substring(0, 8);
        if (String.isBlank(alias)) alias = nickname.length() > 8 ? nickname.substring(0, 8) : nickname;

        return new User(
            Username = username,
            Email = email,
            FirstName = firstName,
            LastName = lastName,
            Alias = alias,
            CommunityNickname = nickname,
            ProfileId = jobSeekerProfile.Id,
            // ContactId = contactId,ContactId = contactId,
            EmailEncodingKey = 'ISO-2022-JP',
            LanguageLocaleKey = 'ja',
            LocaleSidKey = 'ja_JP',
            TimeZoneSidKey = 'Asia/Tokyo'
        );
    }
}