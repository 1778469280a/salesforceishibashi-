/**
 * 求人詳細画面用のコントローラクラス
 * 指定された求人IDに基づいて求人詳細情報を取得し、
 * ログインユーザーがその求人をお気に入り登録しているかどうかを判定します。
 */
public with sharing class JobDetailController {

    /**
     * 指定された求人IDに対応する求人詳細情報を取得します。
     * リクエスト元の LWC から Apex 呼び出し時にキャッシュが有効です (cacheable=true)。
     *
     * @param jobId  取得対象の求人ID (Job__c.Id)
     * @return       求人レコード (Job__c)。関連する会社情報 (Company__r) を含みます。
     * @throws AuraHandledException
     *          - jobId が空白の場合: 「求人IDが未指定です」
     *          - jobId が Salesforce ID 形式でない場合: 「無効な求人ID形式です」
     *          - 指定されたIDの求人が存在しない場合: 「対象の求人が存在しません」
     */
    @AuraEnabled(cacheable=true)
    public static Job__c getJobDetail(String jobId) {
        // 入力チェック: 空白
        if (String.isBlank(jobId)) {
            throw new AuraHandledException('求人IDが未指定です');
        }
        // 入力チェック: Salesforce ID 形式（15桁または18桁）
        if (!Pattern.matches('^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$', jobId)) {
            throw new AuraHandledException('無効な求人ID形式です');
        }

        // 求人詳細と関連会社情報を取得
        List<Job__c> jobList = [
            SELECT 
                Id, 
                JobPosition__c,
                JobCategory1__c,
                WorkLocation2__c,
                Company__c,
                HiringBackground__c,
                JobDescription__c,
                ApplicationQualification__c,
                EmploymentType__c,
                MaxAnnualSalary__c,
                MinAnnualSalary__c,
                WorkLocationRegion__c,
                WorkLocationPrefecture__c,
                TransferRequired__c,
                TransferRemarks__c,
                BenefitsAndWelfare__c,
                HolidaysAndLeave__c,
                WorkingHours__c,
                SpecificConditions__c,
                LastModifiedDate, LastViewedDate,
                JobHighlight1__c, JobHighlight2__c, JobHighlight3__c,
                Company__r.Name,
                Company__r.Industry__c,
                Company__r.BusinessSummary__c,
                Company__r.NumberOfEmployees__c,
                Company__r.MainIndustry__c
            FROM Job__c
            WHERE Id = :jobId
            LIMIT 1
            FOR VIEW
        ];

        // 存在チェック
        if (jobList.isEmpty()) {
            throw new AuraHandledException('対象の求人が存在しません');
        }

        return jobList[0];
    }

    /**
     * ログインユーザーが指定された求人をお気に入り（気になる求人）に登録しているかどうかを返します。
     * リクエスト元の LWC から Apex 呼び出し時にキャッシュが有効です (cacheable=true)。
     *
     * @param jobId  チェック対象の求人ID (Job__c.Id)。空白または null の場合は false を返します。
     * @return       お気に入り登録済みの場合は true、それ以外は false
     */
    @AuraEnabled(cacheable=true)
    public static Boolean getJobFavoriteStatus(String jobId) {
        // IDが指定されていない場合はお気に入りではないとみなす
        if (String.isBlank(jobId)) {
            return false;
        }

        // ログインユーザーが未アーカイブの「気になる求人」として登録している Job__c のIDセットを取得
        Set<Id> favoriteJobIds = new Set<Id>();
        for (InterestedJob__c fav : [
            SELECT Job__c 
            FROM InterestedJob__c
            WHERE CreatedById = :UserInfo.getUserId() 
            AND IsArchive__c = false
        ]) {
            favoriteJobIds.add(fav.Job__c);
        }

        // 指定されたIDがセットに含まれるかどうかを返す
        return favoriteJobIds.contains(jobId);
    }

    @AuraEnabled
    public static void createInquiryProcess(Id jobId) {
        try {
            // 1. 対象の求人情報を取得
            Job__c job = [
                SELECT Id, Company__c, CompanyContactPerson__c 
                FROM Job__c 
                WHERE Id = :jobId 
                LIMIT 1
            ];

            // 2. ログインユーザーの取引先IDを取得（カスタマーコミュニティユーザー想定）
            Id userId = UserInfo.getUserId();
            User currentUser = [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1];
            
            // 3. SelectionProcess__c レコードの作成
            SelectionProcess__c sp = new SelectionProcess__c();
            sp.Company__c = job.Company__c;
            sp.JobPosition__c = job.Id;
            sp.CompanyContactPerson__c = job.CompanyContactPerson__c;
            sp.Candidate__c = currentUser.AccountId; // ログインユーザーの取引先ID
            sp.LatestProcessDate__c = System.now();  // 現在の時間
            sp.LatestProcessStatus__c = '求人詳細問合せ'; // 固定値

            insert sp;

        } catch (Exception e) {
            // LWC側にエラーメッセージを返す
            throw new AuraHandledException('問い合わせ処理に失敗しました: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getSelectionProcessStatus(Id jobId) {
        // ログインユーザーの取引先IDを取得
        Id userId = UserInfo.getUserId();
        List<User> users = [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1];
        
        if (users.isEmpty() || users[0].AccountId == null) {
            return null;
        }
        Id accountId = users[0].AccountId;

        // 対象の求人と取引先に一致する最新の選考プロセスを取得
        List<SelectionProcess__c> processes = [
            SELECT LatestProcessStatus__c 
            FROM SelectionProcess__c 
            WHERE JobPosition__c = :jobId AND Candidate__c = :accountId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];

        if (!processes.isEmpty()) {
            return processes[0].LatestProcessStatus__c;
        }
        return null;
    }
}