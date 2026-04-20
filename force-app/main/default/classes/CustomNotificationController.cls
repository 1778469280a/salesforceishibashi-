public with sharing class CustomNotificationController {
    
    // 通知の一覧を取得（beforeに値があればそれより過去のものを取得）
    @AuraEnabled
    public static String getNotifications(String before) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        
        String domainPath = Url.getOrgDomainUrl().toExternalForm();
        String endpoint = domainPath + '/services/data/v56.0/connect/notifications?size=20';
        
        if (String.isNotBlank(before)) {
            endpoint += '&before=' + before;
        }
        req.setEndpoint(endpoint);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new AuraHandledException('通知取得エラー: ' + res.getBody());
        }
    }

    // 特定の通知を「既読」にする
    @AuraEnabled
    public static void markAsRead(String notificationId) {
        HttpRequest req = new HttpRequest();
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        
        String domainPath = Url.getOrgDomainUrl().toExternalForm();
        req.setEndpoint(domainPath + '/services/data/v56.0/connect/notifications/' + notificationId);
        
        req.setBody('{"read": true}');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('既読更新エラー: ' + res.getBody());
        }
    }

    // すべての通知を「既読」にする
    @AuraEnabled
    public static void markAllAsRead() {
        HttpRequest req = new HttpRequest();
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        
        String domainPath = Url.getOrgDomainUrl().toExternalForm();
        // IDを指定せず、全体のエンドポイントを指定する
        req.setEndpoint(domainPath + '/services/data/v56.0/connect/notifications');
        
        req.setBody('{"read": true}');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('すべて既読更新エラー: ' + res.getBody());
        }
    }
}