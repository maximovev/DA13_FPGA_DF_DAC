Var
    CurrentSCHLib : ISch_Lib;
    CurrentLib : IPCB_Library;

Function CreateAComponent(Name: String) : IPCB_LibComponent;
Var
    PrimitiveList: TInterfaceList;
    PrimitiveIterator: IPCB_GroupIterator;
    PrimitiveHandle: IPCB_Primitive;
    I:  Integer;

Begin
    // Check if footprint already in library
    Result := CurrentLib.GetComponentByName(Name);
    If Result = Nil Then
    Begin
        // Create New Component
        Result := PCBServer.CreatePCBLibComp;
        Result.Name := Name;
    End
    Else
    Begin
        // Clear existin component
        Try
            // Create List with all primitives on board
            PrimitiveList := TInterfaceList.Create;
            PrimitiveIterator := Result.GroupIterator_Create;
            PrimitiveIterator.AddFilter_ObjectSet(AllObjects);
            PrimitiveHandle := PrimitiveIterator.FirstPCBObject;
            While PrimitiveHandle <> Nil Do
            Begin
                PrimitiveList.Add(PrimitiveHandle);
                PrimitiveHandle := PrimitiveIterator.NextPCBObject;
            End;

            // Delete all primitives
            For I := 0 To PrimitiveList.Count - 1 Do
            Begin
                PrimitiveHandle := PrimitiveList.items[i];
                Result.RemovePCBObject(PrimitiveHandle);
                Result.GraphicallyInvalidate;
            End;

        Finally
            Result.GroupIterator_Destroy(PrimitiveIterator);
            PrimitiveList.Free;
        End;
    End;
End; 

Procedure CreateSMDComponentPad(NewPCBLibComp : IPCB_LibComponent, Name : String, Layer : TLayer, X : Real, Y : Real, OffsetX : Real, OffsetY : Real,
                                TopShape : TShape, TopXSize : Real, TopYSize : Real, Rotation: Real, CRRatio : Real, PMExpansion : Real, SMExpansion : Real,
                                PMFromRules : Boolean, SMFromRules : Boolean);
Var
    NewPad                      : IPCB_Pad2;
    PadCache                    : TPadCache;

Begin
    NewPad := PcbServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    NewPad.HoleSize := MMsToCoord(0);
    NewPad.Layer    := Layer;
    NewPad.TopShape := TopShape;
    if TopShape = eRoundedRectangular then
        NewPad.SetState_StackCRPctOnLayer(eTopLayer, CRRatio);
    NewPad.TopXSize := MMsToCoord(TopXSize);
    NewPad.TopYSize := MMsToCoord(TopYSize);
    NewPad.RotateBy(Rotation);
    NewPad.MoveToXY(MMsToCoord(X), MMsToCoord(Y));
    NewPad.Name := Name;

    Padcache := NewPad.GetState_Cache;
    if (PMExpansion <> 0) or (PMFromRules = False) then
    Begin
        Padcache.PasteMaskExpansionValid   := eCacheManual;
        Padcache.PasteMaskExpansion        := MMsToCoord(PMExpansion);
    End;
    if (SMExpansion <> 0) or (SMFromRules = False) then
    Begin
        Padcache.SolderMaskExpansionValid  := eCacheManual;
        Padcache.SolderMaskExpansion       := MMsToCoord(SMExpansion);
    End;
    NewPad.SetState_Cache              := Padcache;

    NewPCBLibComp.AddPCBObject(NewPad);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewPad.I_ObjectAddress);
End;

Procedure CreateComponentTrack(NewPCBLibComp : IPCB_LibComponent, X1 : Real, Y1 : Real, X2 : Real, Y2 : Real, Layer : TLayer, LineWidth : Real, IsKeepout : Boolean);
Var
    NewTrack                    : IPCB_Track;

Begin
    NewTrack := PcbServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    NewTrack.X1 := MMsToCoord(X1);
    NewTrack.Y1 := MMsToCoord(Y1);
    NewTrack.X2 := MMsToCoord(X2);
    NewTrack.Y2 := MMsToCoord(Y2);
    NewTrack.Layer := Layer;
    NewTrack.Width := MMsToCoord(LineWidth);
    NewTrack.IsKeepout := IsKeepout;
    NewPCBLibComp.AddPCBObject(NewTrack);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewTrack.I_ObjectAddress);
End;

Procedure CreateComponentArc(NewPCBLibComp : IPCB_LibComponent, CenterX : Real, CenterY : Real, Radius : Real, StartAngle : Real, EndAngle : Real, Layer : TLayer, LineWidth : Real, IsKeepout : Boolean);
Var
    NewArc                      : IPCB_Arc;

Begin
    NewArc := PCBServer.PCBObjectFactory(eArcObject,eNoDimension,eCreate_Default);
    NewArc.XCenter := MMsToCoord(CenterX);
    NewArc.YCenter := MMsToCoord(CenterY);
    NewArc.Radius := MMsToCoord(Radius);
    NewArc.StartAngle := StartAngle;
    NewArc.EndAngle := EndAngle;
    NewArc.Layer := Layer;
    NewArc.LineWidth := MMsToCoord(LineWidth);
    NewArc.IsKeepout := IsKeepout;
    NewPCBLibComp.AddPCBObject(NewArc);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewArc.I_ObjectAddress);
End;

Function ReadStringFromIniFile(Section: String, Name: String, FilePath: String, IfEmpty: String) : String;
Var
    IniFile                     : TIniFile;

Begin
    result := IfEmpty;
    If FileExists(FilePath) Then
    Begin
        Try
            IniFile := TIniFile.Create(FilePath);

            Result := IniFile.ReadString(Section, Name, IfEmpty);
        Finally
            Inifile.Free;
        End;
    End;
End;

Procedure EnableMechanicalLayers(Zero : Integer);
Var
    Board                       : IPCB_Board;
    MajorADVersion              : Integer;

Begin
    Board := PCBServer.GetCurrentPCBBoard;

    MajorADVersion := StrToInt(Copy((ReadStringFromIniFile('Preference Location','Build',SpecialFolder_AltiumSystem+'\PrefFolder.ini','14')),0,2));

    If MajorADVersion >= 14 Then
    Begin
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(17)).SetState_MechLayerEnabled := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(17)).IsDisplayed[Board] := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(23)).SetState_MechLayerEnabled := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(23)).IsDisplayed[Board] := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(25)).SetState_MechLayerEnabled := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(25)).IsDisplayed[Board] := true;
    End;

    If MajorADVersion < 14 Then
    Begin
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(17)).SetState_MechLayerEnabled := true;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(17)).IsDisplayed[Board]:=True;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(23)).SetState_MechLayerEnabled := true;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(23)).IsDisplayed[Board]:=True;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(25)).SetState_MechLayerEnabled := true;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(25)).IsDisplayed[Board]:=True;
    End;
End;

Procedure CreateComponentQFP64P80_1600X1600X120L60X37N(Zero : integer);
Var
    NewPCBLibComp               : IPCB_LibComponent;
    NewPad                      : IPCB_Pad2;
    NewRegion                   : IPCB_Region;
    NewContour                  : IPCB_Contour;
    STEPmodel                   : IPCB_ComponentBody;
    Model                       : IPCB_Model;
    TextObj                     : IPCB_Text;

Begin
    Try
        PCBServer.PreProcess;

        EnableMechanicalLayers(0);

        NewPcbLibComp := CreateAComponent('QFP64P80_1600X1600X120L60X37N');
        NewPcbLibComp.Name := 'QFP64P80_1600X1600X120L60X37N';
        NewPCBLibComp.Description := 'Quad Flat Pack (QFP), 0.80 mm pitch; square, 16 pin X 16 pin, 14.00 mm L X 14.00 mm W X 1.20 mm H body';
        NewPCBLibComp.Height := MMsToCoord(1.2);

        // Create text object for .Designator
        TextObj := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
        TextObj.UseTTFonts := True;
        TextObj.Layer := eMechanical9;
        TextObj.Text := '.Designator';
        TextObj.Size := MMsToCoord(1.2);
        TextObj.Width := MMsToCoord(0.12);
        NewPCBLibComp.AddPCBObject(TextObj);
        PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,TextObj.I_ObjectAddress);

        CreateSMDComponentPad(NewPCBLibComp, '1', eTopLayer, -7.63, 6, 0, 0, eRectangular, 1.5, 0.57, 180, 0, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '2', eTopLayer, -7.63, 5.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '3', eTopLayer, -7.63, 4.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '4', eTopLayer, -7.63, 3.6, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '5', eTopLayer, -7.63, 2.8, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '6', eTopLayer, -7.63, 2, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '7', eTopLayer, -7.63, 1.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '8', eTopLayer, -7.63, 0.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '9', eTopLayer, -7.63, -0.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '10', eTopLayer, -7.63, -1.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '11', eTopLayer, -7.63, -2, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '12', eTopLayer, -7.63, -2.8, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '13', eTopLayer, -7.63, -3.6, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '14', eTopLayer, -7.63, -4.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '15', eTopLayer, -7.63, -5.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '16', eTopLayer, -7.63, -6, 0, 0, eRoundedRectangular, 1.5, 0.57, 180, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '17', eTopLayer, -6, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '18', eTopLayer, -5.2, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '19', eTopLayer, -4.4, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '20', eTopLayer, -3.6, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '21', eTopLayer, -2.8, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '22', eTopLayer, -2, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '23', eTopLayer, -1.2, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '24', eTopLayer, -0.4, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '25', eTopLayer, 0.4, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '26', eTopLayer, 1.2, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '27', eTopLayer, 2, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '28', eTopLayer, 2.8, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '29', eTopLayer, 3.6, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '30', eTopLayer, 4.4, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '31', eTopLayer, 5.2, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '32', eTopLayer, 6, -7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 270, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '33', eTopLayer, 7.63, -6, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '34', eTopLayer, 7.63, -5.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '35', eTopLayer, 7.63, -4.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '36', eTopLayer, 7.63, -3.6, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '37', eTopLayer, 7.63, -2.8, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '38', eTopLayer, 7.63, -2, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '39', eTopLayer, 7.63, -1.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '40', eTopLayer, 7.63, -0.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '41', eTopLayer, 7.63, 0.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '42', eTopLayer, 7.63, 1.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '43', eTopLayer, 7.63, 2, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '44', eTopLayer, 7.63, 2.8, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '45', eTopLayer, 7.63, 3.6, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '46', eTopLayer, 7.63, 4.4, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '47', eTopLayer, 7.63, 5.2, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '48', eTopLayer, 7.63, 6, 0, 0, eRoundedRectangular, 1.5, 0.57, 0, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '49', eTopLayer, 6, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '50', eTopLayer, 5.2, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '51', eTopLayer, 4.4, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '52', eTopLayer, 3.6, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '53', eTopLayer, 2.8, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '54', eTopLayer, 2, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '55', eTopLayer, 1.2, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '56', eTopLayer, 0.4, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '57', eTopLayer, -0.4, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '58', eTopLayer, -1.2, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '59', eTopLayer, -2, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '60', eTopLayer, -2.8, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '61', eTopLayer, -3.6, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '62', eTopLayer, -4.4, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '63', eTopLayer, -5.2, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '64', eTopLayer, -6, 7.63, 0, 0, eRoundedRectangular, 1.5, 0.57, 90, 49.12, 0, 0, True, True);

        CreateComponentTrack(NewPCBLibComp, -7.4, 6.1875, -7.4, 5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 5.8125, -8, 5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 5.8125, -8, 6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 6.1875, -7.4, 6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 5.3875, -7.4, 5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 5.0125, -8, 5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 5.0125, -8, 5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 5.3875, -7.4, 5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 4.5875, -7.4, 4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 4.2125, -8, 4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 4.2125, -8, 4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 4.5875, -7.4, 4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 3.7875, -7.4, 3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 3.4125, -8, 3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 3.4125, -8, 3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 3.7875, -7.4, 3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 2.9875, -7.4, 2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 2.6125, -8, 2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 2.6125, -8, 2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 2.9875, -7.4, 2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 2.1875, -7.4, 1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 1.8125, -8, 1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 1.8125, -8, 2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 2.1875, -7.4, 2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 1.3875, -7.4, 1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 1.0125, -8, 1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 1.0125, -8, 1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 1.3875, -7.4, 1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 0.5875, -7.4, 0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, 0.2125, -8, 0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 0.2125, -8, 0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 0.5875, -7.4, 0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -0.2125, -7.4, -0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -0.5875, -8, -0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -0.5875, -8, -0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -0.2125, -7.4, -0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -1.0125, -7.4, -1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -1.3875, -8, -1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -1.3875, -8, -1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -1.0125, -7.4, -1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -1.8125, -7.4, -2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -2.1875, -8, -2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -2.1875, -8, -1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -1.8125, -7.4, -1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -2.6125, -7.4, -2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -2.9875, -8, -2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -2.9875, -8, -2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -2.6125, -7.4, -2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -3.4125, -7.4, -3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -3.7875, -8, -3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -3.7875, -8, -3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -3.4125, -7.4, -3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -4.2125, -7.4, -4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -4.5875, -8, -4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -4.5875, -8, -4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -4.2125, -7.4, -4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -5.0125, -7.4, -5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -5.3875, -8, -5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -5.3875, -8, -5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -5.0125, -7.4, -5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -5.8125, -7.4, -6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.4, -6.1875, -8, -6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -6.1875, -8, -5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -5.8125, -7.4, -5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.1875, -7.4, -5.8125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.8125, -7.4, -5.8125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.8125, -8, -6.1875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.1875, -8, -6.1875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.3875, -7.4, -5.0125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.0125, -7.4, -5.0125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.0125, -8, -5.3875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.3875, -8, -5.3875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.5875, -7.4, -4.2125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.2125, -7.4, -4.2125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.2125, -8, -4.5875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.5875, -8, -4.5875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.7875, -7.4, -3.4125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.4125, -7.4, -3.4125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.4125, -8, -3.7875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.7875, -8, -3.7875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.9875, -7.4, -2.6125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.6125, -7.4, -2.6125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.6125, -8, -2.9875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.9875, -8, -2.9875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.1875, -7.4, -1.8125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.8125, -7.4, -1.8125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.8125, -8, -2.1875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.1875, -8, -2.1875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.3875, -7.4, -1.0125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.0125, -7.4, -1.0125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.0125, -8, -1.3875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.3875, -8, -1.3875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.5875, -7.4, -0.2125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.2125, -7.4, -0.2125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.2125, -8, -0.5875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.5875, -8, -0.5875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.2125, -7.4, 0.5875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.5875, -7.4, 0.5875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.5875, -8, 0.2125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.2125, -8, 0.2125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.0125, -7.4, 1.3875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.3875, -7.4, 1.3875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.3875, -8, 1.0125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.0125, -8, 1.0125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.8125, -7.4, 2.1875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.1875, -7.4, 2.1875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.1875, -8, 1.8125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.8125, -8, 1.8125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.6125, -7.4, 2.9875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.9875, -7.4, 2.9875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.9875, -8, 2.6125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.6125, -8, 2.6125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.4125, -7.4, 3.7875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.7875, -7.4, 3.7875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.7875, -8, 3.4125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.4125, -8, 3.4125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.2125, -7.4, 4.5875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.5875, -7.4, 4.5875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.5875, -8, 4.2125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.2125, -8, 4.2125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.0125, -7.4, 5.3875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.3875, -7.4, 5.3875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.3875, -8, 5.0125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.0125, -8, 5.0125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.8125, -7.4, 6.1875, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.1875, -7.4, 6.1875, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.1875, -8, 5.8125, -8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.8125, -8, 5.8125, -7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -6.1875, 7.4, -5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -5.8125, 8, -5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -5.8125, 8, -6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -6.1875, 7.4, -6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -5.3875, 7.4, -5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -5.0125, 8, -5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -5.0125, 8, -5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -5.3875, 7.4, -5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -4.5875, 7.4, -4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -4.2125, 8, -4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -4.2125, 8, -4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -4.5875, 7.4, -4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -3.7875, 7.4, -3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -3.4125, 8, -3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -3.4125, 8, -3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -3.7875, 7.4, -3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -2.9875, 7.4, -2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -2.6125, 8, -2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -2.6125, 8, -2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -2.9875, 7.4, -2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -2.1875, 7.4, -1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -1.8125, 8, -1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -1.8125, 8, -2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -2.1875, 7.4, -2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -1.3875, 7.4, -1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -1.0125, 8, -1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -1.0125, 8, -1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -1.3875, 7.4, -1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -0.5875, 7.4, -0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, -0.2125, 8, -0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -0.2125, 8, -0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -0.5875, 7.4, -0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 0.2125, 7.4, 0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 0.5875, 8, 0.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 0.5875, 8, 0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 0.2125, 7.4, 0.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 1.0125, 7.4, 1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 1.3875, 8, 1.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 1.3875, 8, 1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 1.0125, 7.4, 1.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 1.8125, 7.4, 2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 2.1875, 8, 2.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 2.1875, 8, 1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 1.8125, 7.4, 1.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 2.6125, 7.4, 2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 2.9875, 8, 2.9875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 2.9875, 8, 2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 2.6125, 7.4, 2.6125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 3.4125, 7.4, 3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 3.7875, 8, 3.7875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 3.7875, 8, 3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 3.4125, 7.4, 3.4125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 4.2125, 7.4, 4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 4.5875, 8, 4.5875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 4.5875, 8, 4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 4.2125, 7.4, 4.2125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 5.0125, 7.4, 5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 5.3875, 8, 5.3875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 5.3875, 8, 5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 5.0125, 7.4, 5.0125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 5.8125, 7.4, 6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.4, 6.1875, 8, 6.1875, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 6.1875, 8, 5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 5.8125, 7.4, 5.8125, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.1875, 7.4, 5.8125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.8125, 7.4, 5.8125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.8125, 8, 6.1875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.1875, 8, 6.1875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.3875, 7.4, 5.0125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.0125, 7.4, 5.0125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.0125, 8, 5.3875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.3875, 8, 5.3875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.5875, 7.4, 4.2125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.2125, 7.4, 4.2125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.2125, 8, 4.5875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.5875, 8, 4.5875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.7875, 7.4, 3.4125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.4125, 7.4, 3.4125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.4125, 8, 3.7875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.7875, 8, 3.7875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.9875, 7.4, 2.6125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.6125, 7.4, 2.6125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.6125, 8, 2.9875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.9875, 8, 2.9875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.1875, 7.4, 1.8125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.8125, 7.4, 1.8125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.8125, 8, 2.1875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.1875, 8, 2.1875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.3875, 7.4, 1.0125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.0125, 7.4, 1.0125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.0125, 8, 1.3875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.3875, 8, 1.3875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.5875, 7.4, 0.2125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.2125, 7.4, 0.2125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.2125, 8, 0.5875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.5875, 8, 0.5875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.2125, 7.4, -0.5875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.5875, 7.4, -0.5875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.5875, 8, -0.2125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.2125, 8, -0.2125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.0125, 7.4, -1.3875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.3875, 7.4, -1.3875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.3875, 8, -1.0125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.0125, 8, -1.0125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.8125, 7.4, -2.1875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.1875, 7.4, -2.1875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.1875, 8, -1.8125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.8125, 8, -1.8125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.6125, 7.4, -2.9875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.9875, 7.4, -2.9875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.9875, 8, -2.6125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.6125, 8, -2.6125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.4125, 7.4, -3.7875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.7875, 7.4, -3.7875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.7875, 8, -3.4125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.4125, 8, -3.4125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.2125, 7.4, -4.5875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.5875, 7.4, -4.5875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.5875, 8, -4.2125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.2125, 8, -4.2125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.0125, 7.4, -5.3875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.3875, 7.4, -5.3875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.3875, 8, -5.0125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.0125, 8, -5.0125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.8125, 7.4, -6.1875, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.1875, 7.4, -6.1875, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.1875, 8, -5.8125, 8, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.8125, 8, -5.8125, 7.4, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7, -7, -7, 7, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7, 7, 7, 7, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7, 7, 7, -7, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7, -7, -7, -7, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.05, 6.47, -8.26, 6.47, eTopOverlay, 0.12, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0.35, 0, -0.35, 0, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -7.05, -7.05, -7.05, 5.78, eMechanical13, 0.3, False);
        CreateComponentTrack(NewPCBLibComp, -7.05, 5.78, -5.78, 7.05, eMechanical13, 0.3, False);
        CreateComponentTrack(NewPCBLibComp, -5.78, 7.05, 7.05, 7.05, eMechanical13, 0.3, False);
        CreateComponentTrack(NewPCBLibComp, 7.05, 7.05, 7.05, -7.05, eMechanical13, 0.3, False);
        CreateComponentTrack(NewPCBLibComp, 7.05, -7.05, -7.05, -7.05, eMechanical13, 0.3, False);
        CreateComponentTrack(NewPCBLibComp, -7.05, 6.47, -7.05, 7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -7.05, 7.05, -6.47, 7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -7.05, -6.47, -7.05, -7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -7.05, -7.05, -6.47, -7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 7.05, -6.47, 7.05, -7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 7.05, -7.05, 6.47, -7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 7.05, 6.47, 7.05, 7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 7.05, 7.05, 6.47, 7.05, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -7.25, -7.25, -6.485, -7.25, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -6.485, -7.25, -6.485, -8.58, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -6.485, -8.58, 6.485, -8.58, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6.485, -8.58, 6.485, -7.25, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6.485, -7.25, 7.25, -7.25, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 7.25, -7.25, 7.25, -6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 7.25, -6.485, 8.58, -6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 8.58, -6.485, 8.58, 6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 8.58, 6.485, 7.25, 6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 7.25, 6.485, 7.25, 7.25, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 7.25, 7.25, 6.485, 7.25, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6.485, 7.25, 6.485, 8.58, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6.485, 8.58, -6.485, 8.58, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -6.485, 8.58, -6.485, 7.25, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -6.485, 7.25, -7.25, 7.25, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -7.25, 7.25, -7.25, 6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -7.25, 6.485, -8.58, 6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -8.58, 6.485, -8.58, -6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -8.58, -6.485, -7.25, -6.485, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -7.25, -6.485, -7.25, -7.25, eMechanical15, 0.05, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('\\pa-srv0\Общая работа\GORELKIN\!!!_ПРОЕКТЫ\UCP\UCP\LIB\3D\QFP64P80_1600X1600X120L60X37.STEP', false);
        STEPModel.Layer := ILayer.MechanicalLayer(17);
        STEPmodel.Model := Model;
        STEPmodel.SetState_Identifier(NewPcbLibComp.Name);
        NewPCBLibComp.AddPCBObject(STEPmodel);

        CurrentLib.RegisterComponent(NewPCBLibComp);
        CurrentLib.CurrentComponent := NewPcbLibComp;
    Finally
        PCBServer.PostProcess;
    End;

    CurrentLib.Board.ViewManager_UpdateLayerTabs;
    CurrentLib.Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All' , 255, Client.CurrentView)
End;

Procedure CreateAPCBLibrary(Zero : integer);
Var
    View     : IServerDocumentView;
    Document : IServerDocument;
    TempPCBLibComp : IPCB_LibComponent;

Begin
    If PCBServer = Nil Then
    Begin
        ShowMessage('No PCBServer present. This script inserts a footprint into an existing PCB Library that has the current focus.');
        Exit;
    End;

    CurrentLib := PcbServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('You must have focus on a PCB Library in order for this script to run.');
        Exit;
    End;

    View := Client.GetCurrentView;
    Document := View.OwnerDocument;
    Document.Modified := True;

    // Create And focus a temporary component While we delete items (BugCrunch #10165)
    TempPCBLibComp := PCBServer.CreatePCBLibComp;
    TempPcbLibComp.Name := '___TemporaryComponent___';
    CurrentLib.RegisterComponent(TempPCBLibComp);
    CurrentLib.CurrentComponent := TempPcbLibComp;
    CurrentLib.Board.ViewManager_FullUpdate;

    CreateComponentQFP64P80_1600X1600X120L60X37N(0);

    // Delete Temporary Footprint And re-focus
    CurrentLib.RemoveComponent(TempPCBLibComp);
    CurrentLib.Board.ViewManager_UpdateLayerTabs;
    CurrentLib.Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All', 255, Client.CurrentView)
End;

Procedure CreateALibrary;
Begin
    Screen.Cursor := crHourGlass;

    CreateAPCBLibrary(0);

    Screen.Cursor := crArrow;
End;

End.
