@isTest
public with sharing class ddHttpMockResponse implements HttpCalloutMock {

    private String mode;
    private String recId;

    public ddHttpMockResponse(String mode, String recId) {
        this.mode = mode;
        this.recId = recId;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        if (this.mode == 'object') {
            res.setBody('{"size":1,"totalSize":1,"done":true,"queryLocator":null,"entityTypeName":"CustomObject","records":[{"attributes":{"type":"CustomObject","url":"/services/data/v51.0/tooling/sobjects/CustomObject/' + this.recId +'"},"Description":"This is a test description.","CreatedDate":"2021-04-25T12:46:01.000+0000","CreatedById":"' + UserInfo.getUserId() + '"}]}');
        } else if (this.mode == 'object-fields') {
            res.setBody('{"size":1,"totalSize":1,"done":true,"queryLocator":null,"entityTypeName":"CustomField","records":[{"attributes":{"type":"CustomField","url":"/services/data/v51.0/tooling/sobjects/CustomField/' + this.recId +'"},"DeveloperName":"API_Name__c","CreatedDate":"2021-06-24T02:29:18.000+0000","CreatedById":"' + UserInfo.getUserId() + '"}]}');
        }
        res.setStatusCode(200);
        return res;
    }
}
