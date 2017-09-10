unit uLWDataModule;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Data.Win.ADODB,System.JSON,
  Data.DBXPlatform,System.Generics.Collections, ulwTable,System.Variants,
  System.NetEncoding;

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

  public
    { Public declarations }
     function dataset(resName: string): TJSONArray;
     function cancelDataSet(resName:String):integer;
     function acceptDataSet(resName:String; data:TJSONObject):boolean;
     function updateDataSet(dataSetName: string; data:TJSONObject) :TJSONArray ;
     function updateSp(spName:String; data:TJSONObject):TJSONObject;
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

function TLwDataModule.createAdoDataSet(sql: String): TAdoDataSet;
begin
  result := TADODataSet.Create(self);
  result.Connection := ADOConnection;
  result.CommandText := sql;
  Result.Open;
end;

procedure TLwDataModule.DataModuleCreate(Sender: TObject);
begin
  FResource :=  TObjectDictionary<String,TlwTable>.Create;
  initResources;
end;



function  TLwDataModule.dataset(resName: string): TJSONArray;
var
  lwTable : TLwTable;
  AdoDataSet:TAdoDataSet;
  metaData: TDSInvocationMetadata;
  query:String;
begin
  result := nil;
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
      jsonPair := nil;
      if(field.IsNull) then
      begin
        jsonPair := TJSONPair.Create(field.FieldName, TJSONNull.Create);
      end
      else if(field is TNumericField) then
      begin
         jsonPair := TJSONPair.Create(field.FieldName, TJSONNumber.Create(field.AsFloat));
      end else if (field is TStringField) then begin
         jsonPair := TJSONPair.Create(field.FieldName, field.AsString);
      end else if(field is TBlobField) then
      begin
        jsonPair := TJSONPair.Create(field.FieldName, TNetEncoding.Base64.EncodeBytesToString(TBlobField(field).Value));
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

function TLwDataModule.TryGetValue(const Key: String; out Value: TLwTable): Boolean;
begin
  result :=   FResource.TryGetValue(key, Value);
  if(result) then exit;
  odsQueryTableKey.Close;
  odsQueryTableKey.Parameters.FindParam('tableName').Value := Key;
  odsQueryTableKey.Open;
  if(odsQueryTableKey.RecordCount >0) then
  begin
  //  result := true;
    add(key, odsQueryTableKey.Fields[0].AsString);
    result := FResource.TryGetValue(key, Value);
  end;

end;

function TLwDataModule.updateDataSet(dataSetName: string;
  data: TJSONObject): TJSONArray;
begin

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
      jsonValue := data.GetValue(name);
      if(nil <> jsonValue) then
      begin
        if(param.DataType in [ftString,ftWideString]) then
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

end.
