object LwDataModule: TLwDataModule
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  Height = 245
  Width = 286
  object ADOConnection: TADOConnection
    CommandTimeout = 300
    ConnectionString = 
      'Provider=SQLOLEDB.1;Password=ledway;Persist Security Info=True;U' +
      'ser ID=sa;Initial Catalog=iSamplePub;Data Source=localhost'
    LoginPrompt = False
    Provider = 'SQLOLEDB.1'
    Left = 48
    Top = 40
  end
  object adoSp: TADOStoredProc
    Connection = ADOConnection
    ProcedureName = 'sp_mobile_test'
    Parameters = <
      item
        Name = '@RETURN_VALUE'
        DataType = ftInteger
        Direction = pdReturnValue
        Precision = 10
        Value = 0
      end
      item
        Name = '@Json'
        Attributes = [paNullable]
        DataType = ftWideString
        Size = 2000
        Value = ''
      end
      item
        Name = '@custCardPic'
        Attributes = [paNullable]
        DataType = ftVarBytes
        Size = 2147483647
        Value = Null
      end
      item
        Name = '@errCode'
        Attributes = [paNullable]
        DataType = ftInteger
        Direction = pdInputOutput
        Precision = 10
        Value = 0
      end
      item
        Name = '@errData'
        Attributes = [paNullable]
        DataType = ftWideString
        Direction = pdInputOutput
        Size = 50
        Value = Null
      end>
    Left = 48
    Top = 112
  end
  object odsQueryTableKey: TADODataSet
    Connection = ADOConnection
    CommandText = 
      'SELECT COLUMN_NAME'#13#10'FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE'#13#10'WH' +
      'ERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '#39'.'#39' + QUOTENAME' +
      '(CONSTRAINT_NAME)), '#39'IsPrimaryKey'#39') = 1'#13#10'AND TABLE_NAME = :table' +
      'Name AND TABLE_SCHEMA = SCHEMA_Name()'
    Parameters = <
      item
        Name = 'tableName'
        Size = -1
        Value = Null
      end>
    Prepared = True
    Left = 144
    Top = 56
  end
end
