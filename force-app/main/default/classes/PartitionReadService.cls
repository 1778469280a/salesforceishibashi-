public with sharing class PartitionReadService {
    private static final String BASE_URL = 'https://api-hrbc-jp.porterscloud.com';
    public class Partition {
        public String id { get; set; } 
        public String name { get; set; }
        public Partition(String id, String name) {
            this.id = id;
            this.name = name;
        }
    }
    
    public static String getFirstPartitionId() {
        String endpoint = BASE_URL + '/v1/partition?request_type=1&count=1&start=0';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        
        HttpResponse res = PORTERSHttpClient.send(req);
        if (res.getStatusCode() == 200) {
            Dom.Document doc = new Dom.Document();
            doc.load(res.getBody());
            Dom.XMLNode root = doc.getRootElement();
            
            for (Dom.XMLNode itemNode : root.getChildElements()) {
                if (itemNode.getName() == 'Item') {
                    for (Dom.XMLNode fieldNode : itemNode.getChildElements()) {
                        if (fieldNode.getName() == 'Partition.P_Id') {
                            return fieldNode.getText();
                        }
                    }
                }
            }
        }
        throw new PORTERSException('获取 Partition ID 失败: ' + res.getBody());
    }
    
    public class PORTERSException extends Exception {}
}