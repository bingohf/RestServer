unit Unit3;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs;

type
  TMobileResetService = class(TService)
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  MobileResetService: TMobileResetService;

implementation

{$R *.dfm}

uses FormUnit1,Web.WebReq, uLWDataModule, WebModuleUnit1;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  MobileResetService.Controller(CtrlCode);
end;

function TMobileResetService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TMobileResetService.ServiceCreate(Sender: TObject);
begin
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := WebModuleClass;
  Application.CreateForm(TForm1, Form1);
end;

procedure TMobileResetService.ServiceDestroy(Sender: TObject);
begin
   Form1.Free;
end;

end.
