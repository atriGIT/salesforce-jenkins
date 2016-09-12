/***********************************************************************
** Author:          R Wilson
** Created Date:    13.APRIL.2016
** Description:     Controller class for the Order Form page. Handles every event in the form.
** History:
**              13.APRIL.2016: Created – R Wilson (OAKTON)  
***********************************************************************/
public with sharing class OrderFormController {
    public Blob contentFile {get; set;}
    
    public String fileName {get;set;}
    public String csvString {get;set;}
    public String selectedOption {get;set;}
    public String invoiceId {get;set;}
    public String orderId {get;set;}
    public String saveMode {get;set;}
    public String lineEdit {get;set;}
    public String errorMessage {get;set;}

    public Integer itemIndex {get;set;}
    public Integer itemCounter {get;set;}
    
    public Boolean hasErrors {get;set;}
    public Boolean lineError {get;set;}
    public Boolean showConfirmCancelMessage {get;set;}
    public Boolean showConfirmViewMessage {get;set;}
    public Boolean isFillUpForm {get;set;}
    public Boolean displayPopup {get; set;}
    public Boolean showSparePartFields {get;set;}
    public Boolean showLabourFields {get;set;}
    public Boolean showTravelFields {get;set;}
    public Boolean disableDesc {get;set;}
    public Boolean noGST {get;set;}
    public Boolean invoiceReadOnly {get;set;}

    public Invoice__c invoice {get; set;}
    public Job_Info__c repairOrder {get;set;}
    public Repair_Line__c repairLine {get;set;}
    public transient Repair_Line__c repairLinePreviousState {get;set;}
    public Account acct {get; set;}

    public List<String> saveStatus {get; set;}
    public List<RepairOrderWrapper> orderWrapper {get; set;}
    public List<RepairItemWrapper> itemWrapper {get; set;}
    public List<Repair_Line__c> itemForDelete {get;set;}

    public OrderFormController(){
        User partnerUser = new User();
        itemIndex = 0;
        itemCounter = 0;
        hasErrors = false;
        csvString = '';
        isFillUpForm = false;
        showSparePartFields = true;
        showLabourFields = true;
        showTravelFields = true;
        
        repairOrder = new Job_Info__c();
        invoice = new Invoice__c();
        orderWrapper = new List<RepairOrderWrapper>();
        itemWrapper = new List<RepairItemWrapper>();
        itemForDelete = new List<Repair_Line__c>();

        invoiceId = ApexPages.currentPage().getParameters().get('invoiceid');
        orderId = ApexPages.currentPage().getParameters().get('orderid');
        saveMode = ApexPages.currentPage().getParameters().get('mode');

        System.debug('****INVOICE ID:'+invoiceId);
        System.debug('****ORDER ID:'+orderId);
        System.debug('****MODE:'+saveMode);

        try{
            partnerUser = [SELECT Id, AccountId, ContactId FROM User WHERE Id =:userinfo.getUserId()];
            acct = [SELECT Id, Name, Vendor_ABN__c, Vendor_No__c FROM Account WHERE Id =:partnerUser.AccountId];
        }
        catch(Exception ex){
            System.debug('ERROR ON QUERY:'+ex.getMessage());
        }

        if(invoiceId != null){
            invoiceReadOnly = true;
            invoice = [SELECT Id, Name, Repairer__c, Invoice_Date__c, Invoice_Month__c, Total_Cost__c, Vendor_ABN__c, Vendor_No__c FROM Invoice__c 
                        WHERE Id =:invoiceId];
            
            for(Job_Info__c order: [SELECT Id, Your_Reference__c, Asset_No__c, Repair_Type__c, Client_No__c, End_Datetime__c, Invoice__c, Repair_Order_No__c, 
                                Start_Datetime__c, Total_Cost__c FROM Job_Info__c WHERE Invoice__c =:invoiceId]){

                RepairOrderWrapper job = new RepairOrderWrapper();
                job.repairOrder = order;
                orderWrapper.add(job);
            }

            if(saveMode == 'edit'){
                editRepairOrder();
            }
        }
        else{
            invoiceReadOnly = false;
            invoice.Repairer__c = partnerUser.AccountId;
        }
    }

    public String getDisplayName(){
        String strJobInfo = '';
        if(repairOrder.Repair_Order_No__c != null){
            strJobInfo = 'Repair Order '+repairOrder.Repair_Order_No__c;
        }
        else{
            strJobInfo = 'New Repair Order';
        }
        return strJobInfo;
    }

    public Boolean showReviewButton(){
        return (invoice.Name != null)? true: false;
    }

    public void closePopup() {
        hasErrors = false;
        lineError = false;
        showConfirmCancelMessage = false;
        showConfirmViewMessage = false;
        errorMessage = '';
        displayPopup = false;
    }

    public void addUpdateRepairLine(){
        // add repair line in the warpper
        System.debug('***INVOICE:'+invoice);
        System.debug('***JOB INFO:'+repairOrder);
        System.debug('***LINE Item:'+repairLine);
        
        if(validateRepairLineFields()){
            if(lineEdit != 'Update'){
                itemCounter+=1;
                RepairItemWrapper item = new RepairItemWrapper();
                item.repairOrderNo = repairOrder.Repair_Order_No__c;
                item.repairItem = repairLine;
                item.index = itemCounter;
                itemWrapper.add(item);
                System.debug('****ADD NEW ITEM:'+itemWrapper);
            }
            else{
                for(RepairItemWrapper item: itemWrapper){
                    if(itemIndex == item.index){
                        item.repairItem = repairLine;
                    }
                }
            }
            lineError = false;
            displayPopup = false;
        }
        else{
            lineError = true;
        }
    }    
    
    public void editRepairLine(){
        repairLine = new Repair_Line__c();
        //repairLinePreviousState = new Repair_Line__c();
        
        System.debug('****INDEX SELECTED:'+itemIndex);
        System.debug('****ITEM WRAPPER:'+itemWrapper);
        lineEdit = 'Update';
        for(RepairItemWrapper item: itemWrapper){
            if(itemIndex == item.index){
                repairLine = item.repairItem;
            }
        }
        //repairLinePreviousState = repairLine;
        showEditableFields();
        displayPopup = true;
    }

    public void deleteRepairLine(){
        System.debug('****INDEX SELECTED:'+itemIndex);
        System.debug('****ITEM WRAPPER:'+itemWrapper);
        
        for(Integer i=0; i<= itemWrapper.size(); i++){
            if(itemWrapper[i].index == itemindex){
                System.debug('***ITEM TO BE DELETED:'+itemWrapper[i].index);
                if(itemWrapper[i].repairItem.Id != null){
                    itemForDelete.add(itemWrapper[i].repairItem);
                }
                itemWrapper.remove(i);
                break;
            }
        }
    }

    public void showPopup() {        
        if(validateRepairOrderFields()){
            lineEdit = 'Add';
            repairLine = new Repair_Line__c();
            showEditableFields();
        }
        else{
            hasErrors = true;
        }

        displayPopup = true;
    }
    
    public void showEditableFields(){
        if(repairLine.Repair_Line_Type__c == 'Spare Part'){
            clearOutLineItemValues();
            showSparePartFields = true;
            showLabourFields = false;
            showTravelFields = false;
            disableDesc = false;
        }
        else if(repairLine.Repair_Line_Type__c == 'Labour' || repairLine.Repair_Line_Type__c == 'Aborted Labour'){
            clearOutLineItemValues();
            showLabourFields = true;
            showSparePartFields = false;
            showTravelFields = false;
            disableDesc = false;
        }
        else if(repairLine.Repair_Line_Type__c == 'Travel'){
            clearOutLineItemValues();
            repairLine.Description__c = 'TRAVEL OUTSIDE METRO AREA';
            repairline.Unit_Cost_Incl_GST__c = Decimal.valueOf(System.label.DES_TravelUnitCostInclGST);
            repairline.Unit_Cost_Excl_GST__c = Decimal.valueOf(System.label.DES_TravelUnitCostExclGST);
            showTravelFields = true;
            disableDesc = true;
            showLabourFields = false;
            showSparePartFields = false;
        }
        else{
            clearOutLineItemValues();
            showTravelFields = true;
            disableDesc = false;
            showLabourFields = true;
            showSparePartFields = true;
        }
        
    }
    
    public void clearOutLineItemValues(){
       if(repairLine.Id == null && itemindex == 0){
            repairLine.Quantity__c = null;
            repairLine.Labour_Repair_Timing__c = null; 
            repairLine.Unit_Cost_Excl_GST__c = null; 
            repairLine.Unit_Cost_Incl_GST__c = null; 
            repairLine.Total_Cost_Excl_GST__c = null; 
            repairLine.Total_Cost_Incl_GST__c = null; 
            repairLine.Description__c = null;
            repairLine.DES_Sparepart_Name__c = null; 
            repairLine.Approved_Repairer_Part_Code__c = null;
            repairLine.KMS_Travelled__c = null;
            repairLine.No_GST_Required__c = false;
        }
    }
    
    
    public Boolean validateRepairOrderFields() {
        errorMessage = 'Please fill out required fields before proceeding:<br/>';
        Boolean isValid = true;

        if(invoice.Invoice_Month__c == null){
            errorMessage += '<li>Month </li>';
            isValid = false;
        }
        if(invoice.Invoice_Date__c == null){
            errorMessage += '<li>Invoice Date </li>';
            isValid = false;
        }
        if(invoice.Name == null){
            errorMessage += '<li>Invoice Number </li>';
            isValid = false;
        }
        if(repairOrder.Repair_Order_No__c == null){
            errorMessage += '<li>Repair Order No. </li>';
            isValid = false;
        }
        if(repairOrder.Client_No__c == null){
            errorMessage += '<li>Client No. </li>';
            isValid = false;
        }
        if(repairOrder.Asset_No__c == null){
            errorMessage += '<li>Asset No. </li>';
            isValid = false;
        }
        if(repairOrder.Start_Datetime__c == null){
            errorMessage += '<li>Start Date Time </li>';
            isValid = false;
        }
        if(repairOrder.End_Datetime__c == null){
            errorMessage += '<li>End Date Time </li>';
            isValid = false;
        }
        if(repairOrder.Repair_Type__c == null){
            errorMessage += '<li>Best Fit Repair Type </li>';
            isValid = false;
        }

        return isValid;
    }
    
    public Boolean validateRepairLineFields(){
        errorMessage = '';
        Boolean isValid = true;
        
        if(repairLine.No_GST_Required__c){
            repairLine.Unit_Cost_Incl_GST__c = repairLine.Unit_Cost_Excl_GST__c;
            repairLine.Total_Cost_Incl_GST__c = repairLine.Total_Cost_Excl_GST__c;
        }

        if(showLabourFields){
            if(repairLine.Repair_Line_Type__c == null || repairLine.Quantity__c == null ||
                repairLine.Labour_Repair_Timing__c == null || repairLine.Unit_Cost_Excl_GST__c == null || 
                repairLine.Unit_Cost_Incl_GST__c == null || repairLine.Total_Cost_Excl_GST__c == null || 
                repairLine.Total_Cost_Incl_GST__c == null || 
                (repairLine.Description__c == null || repairLine.Description__c == '')){
                
                isValid = false;
            }
        }

        else if(showSparePartFields){
            if(repairLine.Repair_Line_Type__c == null || repairLine.Quantity__c == null ||
                repairLine.DES_Sparepart_Name__c == null || repairLine.Approved_Repairer_Part_Code__c == null ||
                repairLine.Unit_Cost_Excl_GST__c == null || repairLine.Unit_Cost_Incl_GST__c == null ||
                repairLine.Total_Cost_Excl_GST__c == null || repairLine.Total_Cost_Incl_GST__c == null ||
                (repairLine.Description__c == null || repairLine.Description__c == '')){
                
                isValid = false;
            }
        }

        else if(showTravelFields){
            if(repairLine.Repair_Line_Type__c == null || repairLine.KMS_Travelled__c == null ||
                repairLine.Unit_Cost_Excl_GST__c == null || repairLine.Unit_Cost_Incl_GST__c == null ||
                repairLine.Total_Cost_Excl_GST__c == null || repairLine.Total_Cost_Incl_GST__c == null ||
                (repairLine.Description__c == null || repairLine.Description__c == '')){
                
                isValid = false;
            }
        }
        else{
            if(repairLine.Repair_Line_Type__c == null || repairLine.Quantity__c == null ||
                repairLine.KMS_Travelled__c == null || repairLine.Labour_Repair_Timing__c == null ||
                repairLine.DES_Sparepart_Name__c == null || repairLine.Approved_Repairer_Part_Code__c == null ||
                repairLine.Unit_Cost_Excl_GST__c == null || repairLine.Unit_Cost_Incl_GST__c == null ||
                repairLine.Total_Cost_Excl_GST__c == null || repairLine.Total_Cost_Incl_GST__c == null ||
                (repairLine.Description__c == null || repairLine.Description__c == '')){
                
                isValid = false;
            }
        }
        
        if(!isValid){
            errorMessage = 'Required fields missing<br/>';
        }
        
        if(!repairLine.No_GST_Required__c){
            if(repairLine.Unit_Cost_Incl_GST__c == repairLine.Unit_Cost_Excl_GST__c || 
                repairLine.Total_Cost_Incl_GST__c == repairLine.Total_Cost_Excl_GST__c){
            
                isValid = false;
                errorMessage += 'Values should not be the same for Incl. GST and Excl. GST';
            }
        }
        
        return isValid;
    }

    //method for reading and saving CSV lines
    public PageReference ReadFile(){
        PageReference pref = null;

        System.debug('****CONTENT FILE: '+contentFile);

        saveStatus = new List<String>();
        
        if(contentFile != null){
            if(fileName.contains('xlsx') || fileName.contains('xls')){
                System.debug('***CSV Content: '+csvString);
                List<List<String>> csvLines = null;
                try{
                    csvLines = CSVReader.readIETFRFC4180CSVFile(csvString);
                    if(csvLines == null || csvLines.isEmpty()){
                        System.debug('***ERROR: CSV file contains no lines - error');
                    }
                }catch(Exception e){
                    System.debug('***ERROR: CSV file contains no lines - error');
                    return null;
                }

                ProcessCSV pc = new ProcessCSV();
                saveStatus = pc.saveRepairOrders(csvLines, acct);
            }
            else if(fileName.contains('xml')){
                RepairOrderXMLReader xmlReader = new RepairOrderXMLReader();
                saveStatus = xmlReader.ReadXMLFile(contentFile, acct);
            }
            else{
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Extension Error'));
            }
        }
        
        System.debug('****SAVE STATUS:'+saveStatus);
        if(saveStatus.size() >0){
            if(saveStatus[0] == 'SUCCESS'){
                Attachment attachObj = new Attachment();
                attachObj.Body = contentFile;
                attachObj.ParentId = saveStatus[1];
                attachObj.Name =  fileName;
                attachObj.IsPrivate = false;
                insert attachObj;

                pref = new PageReference('/apex/InvoiceView?invoiceid='+saveStatus[1]+'&mode=submit');
            }
            else{
                String errorList = '';

                if(saveStatus.size() > 10){
                    errorList += 'The file contains too many errors to display. Please review the file and try uploading again. <br/><br/>';
                }

                Integer cnt = 0;
                for(String errors: saveStatus){
                    if(cnt <10){
                        errorList += '- '+errors+'<br/>';
                    }
                    cnt++;
                }

                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, errorList));
            }
        }
        
        return pref;
    }

    public PageReference saveOrder(){
        PageReference pref = null;

        if(validateRepairOrderFields()){
            if(saveRepairOrder()){
                pref = new PageReference('/apex/InvoiceView?invoiceid='+invoice.Id);
                pref.setRedirect(true);
            }
            else{
                //Error saving
            }
        }
        else{
            hasErrors = true;
            displayPopup = true;
        }
        
        return pref;
    }

    public PageReference saveAndNew(){
        PageReference pref = null;

        if(validateRepairOrderFields()){
            if(saveRepairOrder()){
                pref = new PageReference('/apex/OrderForm?invoiceid='+invoice.Id+'&mode=new');
                pref.setRedirect(true);
            }
            else{
                //Error saving
            }
        }
        else{
            hasErrors = true;
            displayPopup = true;
        }

        return pref;
    }

    public PageReference reviewInvoice(){
        PageReference pref = null;
        if(saveRepairOrder()){
            pref = new PageReference('/apex/ReviewSubmit?invoiceid='+invoice.Id);
            pref.setRedirect(true);
        }
        return pref;
    }

    public PageReference cancel(){
        PageReference pref = null;
        pref = new PageReference('/apex/OrderForm');
        pref.setRedirect(true);
        return pref;
    }

    public void confirmCancelAction(){
        showConfirmCancelMessage = true;
        displayPopup = true;
    }

    public void confirmViewAction(){
        showConfirmViewMessage = true;
        displayPopup = true;
    }

    public void editRepairOrder(){
        itemWrapper.clear();
        itemCounter = 0;
        //TODO if can this be put in a map<>
        repairOrder = [SELECT Id, Asset_No__c, Your_Reference__c, Repair_Type__c, Client_No__c, End_Datetime__c, Invoice__c, Repair_Order_No__c, 
                                Start_Datetime__c, Total_Cost__c FROM Job_Info__c WHERE Id =:orderId];
                
        for(Repair_Line__c repairLine: [SELECT Id, Approved_Repairer_Part_Code__c, Description__c, Job_Info__c, KMS_Travelled__c, Labour_Repair_Timing__c, 
                                    Quantity__c, Repair_Line_Type__c, DES_Sparepart_Name__c, No_GST_Required__c, Total_Cost_Excl_GST__c, Total_Cost_Incl_GST__c, 
                                    Unit_Cost_Excl_GST__c, Unit_Cost_Incl_GST__c FROM Repair_Line__c WHERE Job_Info__c =:repairOrder.Id 
                                    ORDER BY Repair_Line_Type__c ]){
            itemCounter+=1;

            RepairItemWrapper line = new RepairItemWrapper();
            line.repairItem = repairLine;
            line.repairOrderNo = repairOrder.Repair_Order_No__c;
            line.index = itemCounter;
            itemWrapper.add(line);
        }

        showConfirmViewMessage = false;
        displayPopup = false;
        
        System.debug('****EDIT ORDER:'+itemWrapper);
    }

    public Boolean saveRepairOrder(){
        Boolean successOnSave = false;
        try{
            if(repairOrder != null && repairOrder.Repair_Order_No__c != null){
                if(Utilities.checkEndDateMonth(invoice.Invoice_Month__c, String.valueOf(repairOrder.End_Datetime__c))){
                    if(invoiceId == null){
                        invoice.Status__c = 'In Progress';
                        invoice.RecordTypeId = Utilities.GetRecordTypeId('Invoice__c','In Progress');
                        insert invoice;
                    } 
        
                    if(itemForDelete.size() > 0){
                        delete itemForDelete;
                    }
                    
                    if(repairOrder.Invoice__c == null){
                        repairOrder.Invoice__c = invoice.Id;
                    }
                    
                    upsert repairOrder;

                    List<Repair_Line__c> lineItems = new List<Repair_Line__c>();
                    for(RepairItemWrapper item: itemWrapper){
                        if(item.repairItem.Job_Info__c == null){
                            item.repairItem.Job_Info__c = repairOrder.Id;
                        }
                        lineItems.add(item.repairItem);
                    }
    
                    upsert lineItems;
                    
                    successOnSave = true;
                }
            }
            
        }
        catch(Exception ex){
            System.debug('***ERROR ON SAVE:'+ex.getMessage());
        }

        return successOnSave;
    }

    public void showSelectedPanel(){
        if(selectedOption == 'form'){
            isFillUpForm = true;
        }
        else{
            isFillUpForm = false;
        }
        system.debug('****FORM:'+isFillUpForm);
    }

    public List<SelectOption> getSelectOption()
    {
        List<SelectOption> returnVal = new List<SelectOption>();
        returnVal.add(new SelectOption('upload','upload my own file'));
        returnVal.add(new SelectOption('form','fill out the form'));
        return returnVal;
    }

}