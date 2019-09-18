unit uLWDataModule;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Data.Win.ADODB,System.JSON,
  Data.DBXPlatform,System.Generics.Collections, ulwTable,System.Variants,
  System.NetEncoding,Windows, DateUtils, Datasnap.DBClient,System.IniFiles,Forms,dialogs;

type
{$METHODINFO ON}
  TLwDataModule = class(TDataModule)
    ADOConnection: TADOConnection;
    adoSp: TADOStoredProc;
    odsQueryTableKey: TADODataSet;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FResource: TObjectDictionary<String,TlwTable>;
    procedure initResources();
    function dataSetToJson(dataset:TDataSet):TJSONArray;
    function createAdoDataSet(sql:String):TAdoDataSet;
    procedure jsonToDataSet(data:TJSONObject; AdoDataSet:TAdoDataSet);
    procedure add(tableName:String; key:String);
    function TryGetValue(const Key: String; out Value: TLwTable): Boolean;
    function getValue(data:TJSONObject; name:String):TJSONValue;
    procedure copyJson(source,dest:TJSONObject);
  public
    { Public declarations }
     function hello():String;
     function hello2():TStream;
     function sql(sql: string): TJSONArray;
     function dataset(resName: string): TJSONArray;
     function cancelDataSet(resName:String):integer;
     function acceptDataSet(resName:String; data:TJSONObject):boolean;
     function updateDataSet(dataSetName: string; data:TJSONObject) :TJSONArray ;
     function updateSp(spName:String; data:TJSONObject):TJSONObject;
     function updateSpDataSet(spName:String; data:TJSONObject):TJSONArray;
     function SpStream(spName:String) :TStream;
     function spJson(SpName:String):TStream;
     function acceptGroup(guid: string;data:TJSONObject): TJSONObject;
     function updateList(spName:String;data:TJSONObject) :TJSONObject;
  end;

var
  LwDataModule: TLwDataModule;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

{ TDataModule1 }



{ TLwDataModule }

function TLwDataModule.acceptDataSet(resName: String;
  data: TJSONObject): boolean;
var
  lwTable : TLwTable;
  AdoDataSet:TAdoDataSet;
  query:String;
begin
  result := false;
  if TryGetValue(resName, lwTable) then
  begin
    try
      query := lwTable.Key +' = ' + QuotedStr(data.GetValue(lwTable.Key).Value);
      AdoDataSet := createAdoDataSet(lwTable.getSql(query));
      if(AdoDataSet.RecordCount >1) then
      begin
         raise Exception.Create('key conflict');
      end else
      begin
         adoDataSet.Edit;
         jsonToDataSet(data, adoDataSet);
         adoDataSet.Post;
         result:= true;
      end;

    finally
      FreeAndNil(AdoDataSet);
    end;
  end else
  begin
       GetInvocationMetadata().ResponseCode := 404;
  end;
end;

function TLwDataModule.acceptGroup(guid: string;data:TJSONObject): TJSONObject;
const
   SQL_SML ='select * from [ScanMasterLine] where series = ''%s''';
var
  macNo :String;
  dataSet:TDataSet;
begin
  macNo := '';
  result := TJSONObject.Create;
  if(data.GetValue('macNo') <> nil)   then
  begin
    macNo := data.GetValue('macNo').Value
  end;
  try
      try
        dataSet := nil;
        dataSet := createAdoDataSet(format(SQL_SML,[ guid]));
        if(dataSet.Eof) then
        begin
          GetInvocationMetadata().ResponseCode := 404;
          exit;
        end;
        if(dataSet.FieldByName('macNo').AsString = '') or (dataSet.FieldByName('macNo').AsString = macNo) then
        begin
          dataSet.Edit;
          dataSet.FieldByName('macNo').AsString := macNo;
          result.AddPair('myTaxNo', dataSet.FieldByName('MyTaxNo').AsString);
          result.AddPair('line', dataSet.FieldByName('line').AsString);
          result.AddPair('sm_server', dataSet.FieldByName('SM_Server').AsString);
          result.AddPair('sm_port', dataSet.FieldByName('SM_PORT').AsString);
          result.AddPair('sm_company', dataSet.FieldByName('SM_Company').AsString);
          dataSet.Post;
        end else
        begin
          result.AddPair('error', 'guid has been assigned');
          GetInvocationMetadata().ResponseCode := 500;
        end;
      except  on e:Exception do
        begin
         result.AddPair('error', e.Message);
         GetInvocationMetadata().ResponseCode := 500;
        end;
      end;

  finally
    if(dataSet <> nil ) then
    begin
      dataSet.Free;
    end;
  end;
end;

procedure TLwDataModule.add(tableName, key: String);
var
    item:TlwTable;
begin
    item := TLwTable.Create;
    item.Name := tableName;
    item.Key := key;
    FResource.Add(tableName, item);
end;

function TLwDataModule.cancelDataSet(resName: String): integer;
var
  lwTable : TLwTable;
  AdoDataSet:TAdoDataSet;
  metaData: TDSInvocationMetadata;
  query:String;
begin
  result := 0;
  if TryGetValue(resName, lwTable) then
  begin

    try
      metaData := GetInvocationMetadata;
      query := metaData.QueryParams.Values['query'];
      if(query ='') then
      begin
        query := '1=1';
      end;
      AdoDataSet := createAdoDataSet(lwTable.getSql(query));
      result := AdoDataSet.RecordCount;
      while adoDAtaSet.RecordCount >0 do
      begin
        adoDataSet.Delete;
      end;

    finally
      FreeAndNil(AdoDataSet);
    end;
  end else begin
       GetInvocationMetadata().ResponseCode := 404;
  end;
end;

procedure TLwDataModule.copyJson(source, dest: TJSONObject);
var
 e:TJSONPairEnumerator;
 pair:TJsonPair;
 name:String;
begin
  e := source.GetEnumerator;
  try
    while e.MoveNext do
    begin
      pair := e.GetCurrent;
      name := pair.JsonString.Value;
      dest.AddPair(pair.Clone as TJsonPair)
    end;
  finally
     e.Free;
  end;
end;



function TLwDataModule.createAdoDataSet(sql: String): TAdoDataSet;
begin
  result := TADODataSet.Create(self);
  result.Connection := ADOConnection;
  result.CommandText := sql;
  Result.Open;
end;

procedure TLwDataModule.DataModuleCreate(Sender: TObject);

  function GetHostName:String;
   var
    ComputerName: array[0..MAX_COMPUTERNAME_LENGTH+1] of char;
    Size: Cardinal;
   begin
      result:='';
      Size := MAX_COMPUTERNAME_LENGTH+1;
      GetComputerName(ComputerName, Size);
      Result:=StrPas(ComputerName);
  end;
var
  computerName :String;
  iniFile:TIniFile;
  iniConnectionStr:String;
begin
  iniConnectionStr := '';
  try
    iniFile := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini')) ;
    iniConnectionStr := iniFile.ReadString('Service','ConnectionString','');
  finally
    FreeAndNil(iniFile);
  end;
  computerName := GetHostName;
  if iniConnectionStr <>'' then
  begin
    ADOConnection.ConnectionString := iniConnectionStr;
  end else
  begin
    if Pos('ledway', computerName) >0 then
    begin
      ADOConnection.ConnectionString := 'Provider=SQLOLEDB.1;Password=Jason@ledway;Persist Security Info=True;User ID=ledwaysa;Initial Catalog=iSamplePub;Data Source=ledway2.database.windows.net'
    end else begin
       ADOConnection.ConnectionString := 'Provider=SQLOLEDB.1;Password=ledway;Persist Security Info=True;User ID=sa;Initial Catalog=iSamplePub;Data Source=vip.ledway.com.tw'
    end;
  end;

  FResource :=  TObjectDictionary<String,TlwTable>.Create;
  initResources;

end;



function  TLwDataModule.dataset(resName: string): TJSONArray;
var
  lwTable : TLwTable;
  AdoDataSet:TAdoDataSet;
  metaData: TDSInvocationMetadata;
  query:String;
  orderBy:String;
  sql:String;
begin
  result := nil;
  if TryGetValue(resName, lwTable) then
  begin
    try
      metaData := GetInvocationMetadata;
      query := metaData.QueryParams.Values['query'];
      orderBy := metaData.QueryParams.Values['orderBy'];
      if(query ='') then
      begin
        query := '1=1';
      end;
      sql := lwTable.getSql(query) + orderBy;
      AdoDataSet := createAdoDataSet(sql);
      result := dataSetToJson(AdoDataSet);
    finally
      FreeAndNil(AdoDataSet);
    end;
  end else
  begin
    GetInvocationMetadata().ResponseCode := 404;
  end;
end;





function TLwDataModule.dataSetToJson(dataset: TDataSet): TJSONArray;
var
  i:integer;
  field:TField;
  jsonPair:TJSONPair;
  item:TJSONObject;
  fieldName:String;
begin
  dataSet.Open;
  result := TJSONArray.Create;
  dataSet.First;
  while not dataSet.eof do
  begin
    item := TJSONObject.Create;
    for i := 0 to DataSet.FieldCount -1 do
    begin
      field := DataSet.Fields[i];
      fieldName := field.FieldName;
      fieldName := LowerCase(fieldName) ;
      jsonPair := nil;
      if(field.IsNull) then
      begin
        jsonPair := TJSONPair.Create(FieldName, TJSONNull.Create);
      end  else if field is TDateTimeField then
      begin
         jsonPair :=  TJSONPair.Create(FieldName, DateToIso8601(TDateTimeField(field).Value, false));
      end
      else if(field is TNumericField) then
      begin
         jsonPair := TJSONPair.Create(FieldName, TJSONNumber.Create(field.AsFloat));
      end else if (field is TStringField) then begin
         jsonPair := TJSONPair.Create(FieldName, field.AsString);
      end else if(field is TBlobField) then
      begin
        jsonPair := TJSONPair.Create(FieldName, TNetEncoding.Base64.EncodeBytesToString(TBlobField(field).Value));
      end;
      if(jsonPair <> nil) then
      begin
         item.AddPair(jsonPair);
      end;

    end;

    Result.Add(item);
    dataSet.Next;
  end;


end;


function TLwDataModule.getValue(data: TJSONObject; name: String): TJSONValue;
var
 e:TJSONPairEnumerator;

begin
  result:= nil;
  e := data.GetEnumerator;
  try
    while e.MoveNext do
    begin
      if (UpperCase(name) = UpperCase(e.GetCurrent.JsonString.Value)) then
      begin
        result := e.GetCurrent.JsonValue;
         break;
      end;
    end;
  finally
     e.Free;
  end;
end;

function TLwDataModule.hello: String;
begin
  result := 'hello';
end;

function TLwDataModule.hello2: TStream;
var
  writer:TSTreamWriter;
begin
  result:= TMemoryStream.Create;
  writer := TStreamWriter.Create(result, TEncoding.UTF8);
  writer.Write('abcdefgÖÐ¹ú');
  writer.Close;
end;

procedure TLwDataModule.initResources;
begin
  add('RDID1','localGUID');
  //add('Table_Test','StringField');
end;

procedure TLwDataModule.jsonToDataSet(data: TJSONObject;
  AdoDataSet: TAdoDataSet);
var i:integer;
  field:TField;
  jsonValue:TJSONValue;
begin
  for i := 0 to adoDataSet.FieldCount-1 do
  begin
    field := adoDataSet.Fields[i];
    jsonValue := data.GetValue(field.FieldName) ;
    if(jsonValue <> nil) then
    begin
      if field is TBlobField then
      begin
         TBlobField(field).Value := TNetEncoding.Base64.DecodeStringToBytes(jsonValue.Value);
      end else
      begin
        field.AsString := jsonValue.Value;
      end;
    end;
  end;


end;


function TLwDataModule.spJson(SpName: String): TStream;
var
  param:TParameter;
  i:integer;
  name:String;
  value:String;
  metaData: TDSInvocationMetadata;
  blobFieldName:String;
  writer:TStreamWriter;
  adoSp:TADOStoredProc;
  outfield:TField;
begin
  result := TMemoryStream.Create();
  adoSp := TADOStoredProc.Create(self);
  writer := TStreamWriter.Create(result, TEncoding.UTF8);
  try
    try
      adoSp.Connection := AdoConnection;
      adoSp.CommandTimeout := 300;
      adoSp.ProcedureName := spName;
      adoSp.Parameters.Clear;
      adoSp.Prepared := false;
      adoSp.Prepared := true;
      adoSp.Parameters.Refresh;
      metaData := GetInvocationMetadata;
      blobFieldName := metaData.QueryParams.Values['out_field'];
      for i := 0 to adoSp.Parameters.Count -1 do
      begin
        param :=  adoSp.Parameters.Items[i];
        if(param.Direction  in [ pdInput, pdInputOutput] )  then
        begin
          name := param.Name;
          name := copy(name, 2, length(name) -1 );
          value := metaData.QueryParams.Values[name];
          if(value <> '') then
          begin
            if(param.DataType in [ftString,ftWideString]) then
            begin
              param.Value := value;
            end else if(param.DataType in [ftInteger]) then
            begin
               param.Value := strtoInt(value);
            end;
            continue;
          end ;
          param.Value := Null;
        end;
      end;
      adoSp.Open;
      if adoSp.RecordCount =0  then
      begin
        writer.Write('[]');
      end else
      begin
        outField := adoSp.Fields[0];
        adosp.First;
        while not adoSp.Eof do
        begin
          writer.Write(outField.AsString);
          adoSp.Next;
        end;
      end;

      GetInvocationMetadata().ResponseCode := 200;
      GetInvocationMetadata().ResponseContentType := 'text/html;charset=UTF-8';
    except on e:Exception do
      begin
       GetInvocationMetadata().ResponseCode := 500;
       writer.writeline(e.message);
      end;
    end;
  finally
     adoSp.Free;
     if writer <> nil  then
     begin
       writer.Close;
       writer.Free;
     end;
  end;
end;

function TLwDataModule.SpStream(spName:String): TStream;
var
  param:TParameter;
  i:integer;
  name:String;
  value:String;
  metaData: TDSInvocationMetadata;
  blobFieldName:String;
  outField : TField;
  adoSp:TADOStoredProc;
begin
  adoSp := TADOStoredProc.Create(self);
  try
    adoSp.Connection := AdoConnection;
    adoSp.CommandTimeout := 300;
    adoSp.ProcedureName := spName;
    adoSp.Parameters.Clear;
    adoSp.Prepared := false;
    adoSp.Prepared := true;
    adoSp.Parameters.Refresh;
    metaData := GetInvocationMetadata;
    blobFieldName := metaData.QueryParams.Values['out_field'];
    for i := 0 to adoSp.Parameters.Count -1 do
    begin
      param :=  adoSp.Parameters.Items[i];
      if(param.Direction  in [ pdInput, pdInputOutput] )  then
      begin
        name := param.Name;
        name := copy(name, 2, length(name) -1 );
        value := metaData.QueryParams.Values[name];
        if(value <> '') then
        begin
          if(param.DataType in [ftString,ftWideString]) then
          begin
            param.Value := value;
          end else if(param.DataType in [ftInteger]) then
          begin
             param.Value := strtoInt(value);
          end;
          continue;
        end ;
        param.Value := Null;
      end;
    end;
    adoSp.Open;
    outField := adoSp.FieldByName(blobFieldName);
    if outField.IsBlob then
    begin
      result := TMemoryStream.Create();
      TBlobField(outField).SaveToStream(result);
      result.Position := 0;
      GetInvocationMetadata().ResponseContentType := 'image/png'
    end else
    begin
      GetInvocationMetadata().ResponseCode := 404;
    end;
  finally
     adoSp.Free;
  end;
end;

function TLwDataModule.sql(sql: string): TJSONArray;
var
  AdoDataSet:TAdoDataSet;
  metaData: TDSInvocationMetadata;
begin
  result := nil;
  try
    metaData := GetInvocationMetadata;
    AdoDataSet := createAdoDataSet(sql);
    result := dataSetToJson(AdoDataSet);
  finally
    FreeAndNil(AdoDataSet);
  end;
end;

function TLwDataModule.TryGetValue(const Key: String; out Value: TLwTable): Boolean;
begin
  result :=   FResource.TryGetValue(key, Value);
  if(result) then exit;
  odsQueryTableKey.Close;
  odsQueryTableKey.Parameters.FindParam('tableName').Value := Key;
  odsQueryTableKey.Open;
   add(key, odsQueryTableKey.Fields[0].AsString);
    result := FResource.TryGetValue(key, Value);

end;

function TLwDataModule.updateDataSet(dataSetName: string;
  data: TJSONObject): TJSONArray;
begin

end;

function TLwDataModule.updateList(spName:String;data: TJSONObject): TJSONObject;
var strings:TStringList;
var tempJson :  TJSONObject;
var i:integer;
begin
  result :=  TJSONObject.Create;
  strings := TStringList.Create;
  tempJson :=   data.clone as TJSONObject;
  strings.Text := trim(data.GetValue('strings').Value);
  result := TJSONObject.Create;
  for i  := 0 to strings.Count - 1 do
  begin
     tempJson.RemovePair('string');
     tempJson.AddPair('string',strings[i]);
     FreeAndNil(result);
     //showmessage(tempJson.ToJSON);
     result := updateSp(spName,  tempJson)
  end;



end;

function TLwDataModule.updateSp(spName: String; data: TJSONObject): TJSONObject;
var
  emuerator:TJSONPairEnumerator;
  jsonItem:TJSONPair;
  param:TParameter;
  i:integer;
  name:String;
  jsonValue:TJSONValue;
begin
  adoSp.ProcedureName := spName;
  adoSp.Parameters.Clear;
  adoSp.Prepared := false;
  adoSp.Prepared := true;
  adoSp.Parameters.Refresh;


  for i := 0 to adoSp.Parameters.Count -1 do
  begin
    param :=  adoSp.Parameters.Items[i];
    if(param.Direction  in [ pdInput, pdInputOutput] )  then
    begin
      name := param.Name;
      name := copy(name, 2, length(name) -1 );
      jsonValue := getValue(data, name);
      if(nil <> jsonValue) then
      begin
        if(param.DataType in [ftString,ftWideString, ftInteger]) then
        begin
          param.Value := jsonValue.Value;
        end else if(param.DataType in [ftBytes, ftVarBytes]) then
        begin
           param.Value := TNetEncoding.Base64.DecodeStringToBytes(jsonValue.Value);
        end;
        continue;
      end ;
      param.Value := Null;
    end;
  end;


  adoSp.ExecProc;
  result := TJSONObject.Create;
  for i := 0 to adoSp.Parameters.Count -1 do
  begin
    param :=  adoSp.Parameters.Items[i];
    if(param.Direction  in [pdInputOutput, pdOutput, pdReturnValue] )  then
    begin
      name :=  param.Name;
      name := copy(name, 2, length(name)-1);
      if(VarIsNull( param.Value))  then
      begin
         jsonItem := TJSONPair.Create(Name, TJSONNull.Create);
      end else
      if(param.DataType in   [ftString, ftWideString]) then
      begin
         jsonItem := TJSONPair.Create(name, param.Value);
      end else begin
         jsonItem := TJSONPair.Create(name, TJSONNumber.Create(param.Value));
      end;
      result.AddPair(jsonItem);
    end;
  end;
end;

function TLwDataModule.updateSpDataSet(spName: String;
  data: TJSONObject): TJSONArray;
var
  emuerator:TJSONPairEnumerator;
  jsonItem:TJSONPair;
  param:TParameter;
  i:integer;
  name:String;
  jsonValue:TJSONValue;
begin
  adoSp.ProcedureName := spName;
  adoSp.Parameters.Clear;
  adoSp.Prepared := false;
  adoSp.Prepared := true;
  adoSp.Parameters.Refresh;


  for i := 0 to adoSp.Parameters.Count -1 do
  begin
    param :=  adoSp.Parameters.Items[i];
    if(param.Direction  in [ pdInput, pdInputOutput] )  then
    begin
      name := param.Name;
      name := copy(name, 2, length(name) -1 );
      jsonValue := getValue(data, name);
      if(nil <> jsonValue) then
      begin
        if(param.DataType in [ftString,ftWideString, ftInteger]) then
        begin
          param.Value := jsonValue.Value;
        end else if(param.DataType in [ftBytes, ftVarBytes]) then
        begin
           param.Value := TNetEncoding.Base64.DecodeStringToBytes(jsonValue.Value);
        end;
        continue;
      end ;
      param.Value := Null;
    end;
  end;
  adoSp.Open;
  result := dataSetToJson(adoSp);
end;

end.
