unit uLwTable;

interface

uses
  System.SysUtils, System.Classes;
type
  TLwTable = class
  public
    Name:String;
    Key:String;
    function getSql(query:String):String;
    function getSqlWithKeyValue(KeyValue:String) :String;
  end;


implementation

{ TLwTable }

function TLwTable.getSql(query:String): String;
begin
  result := Format('select * from %s where %s', [name,query]);
end;

function TLwTable.getSqlWithKeyValue(KeyValue: String): String;
begin

end;

end.
