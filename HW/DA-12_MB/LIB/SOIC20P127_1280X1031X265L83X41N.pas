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

Procedure CreateComponentSOIC20P127_1280X1031X265L83X41N(Zero : integer);
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

        NewPcbLibComp := CreateAComponent('SOIC20P127_1280X1031X265L83X41N');
        NewPcbLibComp.Name := 'SOIC20P127_1280X1031X265L83X41N';
        NewPCBLibComp.Description := 'Small Outline IC (SOIC), 1.27 mm pitch; 20 pin, 12.80 mm L X 7.50 mm W X 2.65 mm H body';
        NewPCBLibComp.Height := MMsToCoord(2.65);

        // Create text object for .Designator
        TextObj := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
        TextObj.UseTTFonts := True;
        TextObj.Layer := eMechanical9;
        TextObj.Text := '.Designator';
        TextObj.Size := MMsToCoord(1.5);
        TextObj.Width := MMsToCoord(0.15);
        NewPCBLibComp.AddPCBObject(TextObj);
        PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,TextObj.I_ObjectAddress);

        CreateSMDComponentPad(NewPCBLibComp, '1', eTopLayer, -4.62, 5.715, 0, 0, eRectangular, 2.2, 0.7, 180, 0, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '2', eTopLayer, -4.62, 4.445, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '3', eTopLayer, -4.62, 3.175, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '4', eTopLayer, -4.62, 1.905, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '5', eTopLayer, -4.62, 0.635, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '6', eTopLayer, -4.62, -0.635, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '7', eTopLayer, -4.62, -1.905, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '8', eTopLayer, -4.62, -3.175, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '9', eTopLayer, -4.62, -4.445, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '10', eTopLayer, -4.62, -5.715, 0, 0, eRoundedRectangular, 2.2, 0.7, 180, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '11', eTopLayer, 4.62, -5.715, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '12', eTopLayer, 4.62, -4.445, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '13', eTopLayer, 4.62, -3.175, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '14', eTopLayer, 4.62, -1.905, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '15', eTopLayer, 4.62, -0.635, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '16', eTopLayer, 4.62, 0.635, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '17', eTopLayer, 4.62, 1.905, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '18', eTopLayer, 4.62, 3.175, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '19', eTopLayer, 4.62, 4.445, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '20', eTopLayer, 4.62, 5.715, 0, 0, eRoundedRectangular, 2.2, 0.7, 0, 51.43, 0, 0, True, True);

        CreateComponentTrack(NewPCBLibComp, -4.32, 5.92, -4.32, 5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 5.51, -5.155, 5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 5.51, -5.155, 5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 5.92, -4.32, 5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 4.65, -4.32, 4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 4.24, -5.155, 4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 4.24, -5.155, 4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 4.65, -4.32, 4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 3.38, -4.32, 2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 2.97, -5.155, 2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 2.97, -5.155, 3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 3.38, -4.32, 3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 2.11, -4.32, 1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 1.7, -5.155, 1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 1.7, -5.155, 2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 2.11, -4.32, 2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 0.84, -4.32, 0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, 0.43, -5.155, 0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 0.43, -5.155, 0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, 0.84, -4.32, 0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -0.43, -4.32, -0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -0.84, -5.155, -0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -0.84, -5.155, -0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -0.43, -4.32, -0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -1.7, -4.32, -2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -2.11, -5.155, -2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -2.11, -5.155, -1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -1.7, -4.32, -1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -2.97, -4.32, -3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -3.38, -5.155, -3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -3.38, -5.155, -2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -2.97, -4.32, -2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -4.24, -4.32, -4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -4.65, -5.155, -4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -4.65, -5.155, -4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -4.24, -4.32, -4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -5.51, -4.32, -5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.32, -5.92, -5.155, -5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -5.92, -5.155, -5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.155, -5.51, -4.32, -5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -5.92, 4.32, -5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -5.51, 5.155, -5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -5.51, 5.155, -5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -5.92, 4.32, -5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -4.65, 4.32, -4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -4.24, 5.155, -4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -4.24, 5.155, -4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -4.65, 4.32, -4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -3.38, 4.32, -2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -2.97, 5.155, -2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -2.97, 5.155, -3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -3.38, 4.32, -3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -2.11, 4.32, -1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -1.7, 5.155, -1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -1.7, 5.155, -2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -2.11, 4.32, -2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -0.84, 4.32, -0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, -0.43, 5.155, -0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -0.43, 5.155, -0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, -0.84, 4.32, -0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 0.43, 4.32, 0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 0.84, 5.155, 0.84, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 0.84, 5.155, 0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 0.43, 4.32, 0.43, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 1.7, 4.32, 2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 2.11, 5.155, 2.11, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 2.11, 5.155, 1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 1.7, 4.32, 1.7, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 2.97, 4.32, 3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 3.38, 5.155, 3.38, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 3.38, 5.155, 2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 2.97, 4.32, 2.97, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 4.24, 4.32, 4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 4.65, 5.155, 4.65, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 4.65, 5.155, 4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 4.24, 4.32, 4.24, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 5.51, 4.32, 5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.32, 5.92, 5.155, 5.92, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 5.92, 5.155, 5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.155, 5.51, 4.32, 5.51, ILayer.MechanicalLayer(25), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.75, -6.4, -3.75, 6.4, ILayer.MechanicalLayer(23), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.75, 6.4, 3.75, 6.4, ILayer.MechanicalLayer(23), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 3.75, 6.4, 3.75, -6.4, ILayer.MechanicalLayer(23), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 3.75, -6.4, -3.75, -6.4, ILayer.MechanicalLayer(23), 0.05, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0.35, 0, -0.35, 0, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.8, -6.5, -3.8, 5.23, eMechanical13, 0.35, False);
        CreateComponentTrack(NewPCBLibComp, -3.8, 5.23, -2.53, 6.5, eMechanical13, 0.35, False);
        CreateComponentTrack(NewPCBLibComp, -2.53, 6.5, 3.8, 6.5, eMechanical13, 0.35, False);
        CreateComponentTrack(NewPCBLibComp, 3.8, 6.5, 3.8, -6.5, eMechanical13, 0.35, False);
        CreateComponentTrack(NewPCBLibComp, 3.8, -6.5, -3.8, -6.5, eMechanical13, 0.35, False);
        CreateComponentTrack(NewPCBLibComp, -3.8, 6.5, 3.8, 6.5, eTopOverlay, 0.2, False);
        CreateComponentTrack(NewPCBLibComp, -3.8, -6.5, 3.8, -6.5, eTopOverlay, 0.2, False);
        CreateComponentTrack(NewPCBLibComp, -3.8, 6.365, -5.62, 6.365, eTopOverlay, 0.2, False);
        CreateComponentTrack(NewPCBLibComp, -4, -6.7, 4, -6.7, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4, -6.7, 4, -6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4, -6.265, 5.92, -6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.92, -6.265, 5.92, 6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.92, 6.265, 4, 6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4, 6.265, 4, 6.7, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4, 6.7, -4, 6.7, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4, 6.7, -4, 6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4, 6.265, -5.92, 6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.92, 6.265, -5.92, -6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.92, -6.265, -4, -6.265, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4, -6.265, -4, -6.7, eMechanical15, 0.05, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('\\pa-srv0\Общая работа\GORELKIN\!!!_ПРОЕКТЫ\UCP\UCP\LIB\3D\SOIC20P127_1280X1031X265L83X41N.STEP', false);
        STEPModel.Layer := ILayer.MechanicalLayer(17);
        STEPmodel.Model := Model;
        STEPmodel.SetState_Identifier(NewPcbLibComp.Name);
        NewPCBLibComp.AddPCBObject(STEPmodel);


        // If you see an Undeclared Identifier : PCBLibrariesUserScript error...
        // Go to DXP -> Preferences. Then choose Scripting System, and then Global Projects.
        // Add the PCBLibrariesUserScript project and then your script will be able to call it.

        PCBLibrariesUserScript(NewPCBLibComp);

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

    CreateComponentSOIC20P127_1280X1031X265L83X41N(0);

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
