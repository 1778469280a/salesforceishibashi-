public with sharing class CareerHistoryController {

    // LWCとデータをやり取りするためのラッパークラス
    public class CareerWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String startDateInput { get; set; }
        @AuraEnabled public String endDateInput { get; set; }
        @AuraEnabled public Boolean isCurrentJob { get; set; }
        @AuraEnabled public String annualIncome { get; set; }
        @AuraEnabled public String jobDescription { get; set; }
        @AuraEnabled public String jobGroup { get; set; }
        @AuraEnabled public String jobGroupOption { get; set; } 
    }

    // ==========================================
    // 初期データの取得処理
    // ==========================================
    @AuraEnabled
    public static List<CareerWrapper> getCareerHistory() {
        List<CareerWrapper> careerList = new List<CareerWrapper>();
        Account acc = new Account();

        try {
            User currentUser = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            
            if (currentUser.AccountId != null) {
                acc = [
                    SELECT Id,
                           EmployerName1__c, CurrentAnnualIncome1__c, JobDescription1__pc, WorkStartDate1__c, WorkEndDate1__c, Occupation1__c, Occupation1Category__c,
                           EmployerName2__pc, JobDescription2__pc, WorkStartDate2__pc, WorkEndDate2__pc, Occupation2__c, Occupation2Category__c,
                           EmployerName3__pc, JobDescription3__pc, WorkStartDate3__pc, WorkEndDate3__pc, Occupation3__c, Occupation3Category__c,
                           CareerFourAndLater__pc
                    FROM Account
                    WHERE Id = :currentUser.AccountId
                    LIMIT 1
                ];
            }
        } catch (Exception e) {
            System.debug('取引先の取得に失敗しました: ' + e.getMessage());
        }

        // --- 1社目の詰め込み ---
        CareerWrapper c1 = new CareerWrapper();
        c1.id = '1';
        c1.companyName = nullToEmpty(acc.EmployerName1__c);
        c1.annualIncome = nullToEmpty(acc.CurrentAnnualIncome1__c);
        c1.jobDescription = nullToEmpty(acc.JobDescription1__pc);
        // ★修正：親と子のマッピングを入れ替え
        c1.jobGroup = nullToEmpty(acc.Occupation1__c); // ★親項目
        c1.jobGroupOption = nullToEmpty(acc.Occupation1Category__c); // ★子項目
        c1.startDateInput = formatDateToYYYYMM(acc.WorkStartDate1__c);
        c1.endDateInput = formatDateToYYYYMM(acc.WorkEndDate1__c);
        c1.isCurrentJob = (acc.WorkEndDate1__c == null); // 終了日が空なら現在就業中
        careerList.add(c1);

        // --- 2社目の詰め込み ---
        CareerWrapper c2 = new CareerWrapper();
        c2.id = '2';
        c2.companyName = nullToEmpty(acc.EmployerName2__pc);
        c2.jobDescription = nullToEmpty(acc.JobDescription2__pc);
        // ★修正：親と子のマッピングを入れ替え
        c2.jobGroup = nullToEmpty(acc.Occupation2__c); // ★親項目
        c2.jobGroupOption = nullToEmpty(acc.Occupation2Category__c); // ★子項目
        c2.startDateInput = formatDateToYYYYMM(acc.WorkStartDate2__pc);
        c2.endDateInput = formatDateToYYYYMM(acc.WorkEndDate2__pc);
        c2.isCurrentJob = false;
        careerList.add(c2);

        // --- 3社目の詰め込み ---
        CareerWrapper c3 = new CareerWrapper();
        c3.id = '3';
        c3.companyName = nullToEmpty(acc.EmployerName3__pc);
        c3.jobDescription = nullToEmpty(acc.JobDescription3__pc);
        // ★修正：親と子のマッピングを入れ替え
        c3.jobGroup = nullToEmpty(acc.Occupation3__c); // ★親項目
        c3.jobGroupOption = nullToEmpty(acc.Occupation3Category__c); // ★子項目
        c3.startDateInput = formatDateToYYYYMM(acc.WorkStartDate3__pc);
        c3.endDateInput = formatDateToYYYYMM(acc.WorkEndDate3__pc);
        c3.isCurrentJob = false;
        careerList.add(c3);

        // --- 4社目の詰め込み ---
        CareerWrapper c4 = new CareerWrapper();
        c4.id = '4';
        c4.jobDescription = nullToEmpty(acc.CareerFourAndLater__pc);
        c4.isCurrentJob = false;
        careerList.add(c4);

        return careerList;
    }

    // ==========================================
    // データの保存処理
    // ==========================================
    @AuraEnabled
    public static void saveCareers(List<CareerWrapper> careerList) {
        if (careerList == null || careerList.isEmpty()) return;

        User currentUser = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (currentUser.AccountId == null) throw new AuraHandledException('取引先情報が見つかりません。');
        
        Account accToUpdate = new Account(Id = currentUser.AccountId);

        for (CareerWrapper data : careerList) {
            if (data.id == '1') {
                accToUpdate.EmployerName1__c = data.companyName;
                accToUpdate.CurrentAnnualIncome1__c = data.annualIncome;
                accToUpdate.JobDescription1__pc = data.jobDescription;
                // ★修正：親と子のマッピングを入れ替え
                accToUpdate.Occupation1__c = data.jobGroup; // ★親項目
                accToUpdate.Occupation1Category__c = data.jobGroupOption; // ★子項目
                accToUpdate.WorkStartDate1__c = parseDate(data.startDateInput);
                accToUpdate.WorkEndDate1__c = data.isCurrentJob ? null : parseDate(data.endDateInput);
            }
            else if (data.id == '2') {
                accToUpdate.EmployerName2__pc = data.companyName;
                accToUpdate.JobDescription2__pc = data.jobDescription;
                // ★修正：親と子のマッピングを入れ替え
                accToUpdate.Occupation2__c = data.jobGroup; // ★親項目
                accToUpdate.Occupation2Category__c = data.jobGroupOption; // ★子項目
                accToUpdate.WorkStartDate2__pc = parseDate(data.startDateInput);
                accToUpdate.WorkEndDate2__pc = parseDate(data.endDateInput);
            }
            else if (data.id == '3') {
                accToUpdate.EmployerName3__pc = data.companyName;
                accToUpdate.JobDescription3__pc = data.jobDescription;
                // ★修正：親と子のマッピングを入れ替え
                accToUpdate.Occupation3__c = data.jobGroup; // ★親項目
                accToUpdate.Occupation3Category__c = data.jobGroupOption; // ★子項目
                accToUpdate.WorkStartDate3__pc = parseDate(data.startDateInput);
                accToUpdate.WorkEndDate3__pc = parseDate(data.endDateInput);
            }
            else if (data.id == '4') {
                accToUpdate.CareerFourAndLater__pc = data.jobDescription; 
            }
        }
        update accToUpdate;
    }

    // ==========================================
    // ヘルパーメソッド群
    // ==========================================
    
    private static String nullToEmpty(String str) { return str == null ? '' : str; }
    
    private static String formatDateToYYYYMM(Date d) {
        if (d == null) return '';
        String m = String.valueOf(d.month());
        if (m.length() == 1) m = '0' + m; 
        return d.year() + '-' + m;
    }

    private static Date parseDate(String dateStr) {
        if (String.isBlank(dateStr)) return null;
        try {
            List<String> parts = dateStr.split('-');
            return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 1);
        } catch(Exception e) { return null; }
    }
}