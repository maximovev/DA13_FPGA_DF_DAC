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

Procedure CreateComponentINDM320X250X220L90X200N(Zero : integer);
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

        NewPcbLibComp := CreateAComponent('INDM320X250X220L90X200N');
        NewPcbLibComp.Name := 'INDM320X250X220L90X200N';
        NewPCBLibComp.Description := 'Inductor, Molded Body; 3.20 mm L X 2.50 mm W X 2.20 mm H body';
        NewPCBLibComp.Height := MMsToCoord(2.2);

        // Create text object for .Designator
        TextObj := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
        TextObj.UseTTFonts := True;
        TextObj.Layer := eMechanical9;
        TextObj.Text := '.Designator';
        TextObj.Size := MMsToCoord(1.2);
        TextObj.Width := MMsToCoord(0.12);
        NewPCBLibComp.AddPCBObject(TextObj);
        PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,TextObj.I_ObjectAddress);

        CreateSMDComponentPad(NewPCBLibComp, '1', eTopLayer, -1.325, 0, 0, 0, eRoundedRectangular, 1.77, 2.22, 180, 28.25, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '2', eTopLayer, 1.325, 0, 0, 0, eRoundedRectangular, 1.77, 2.22, 0, 28.25, 0, 0, True, True);

        CreateComponentTrack(NewPCBLibComp, -0.7, 1, -0.7, -1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.7, -1, -1.6, -1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.6, -1, -1.6, 1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.6, 1, -0.7, 1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.7, -1, 0.7, 1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.7, 1, 1.6, 1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.6, 1, 1.6, -1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.6, -1, 0.7, -1, ILayer.MechanicalLayer(25), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.6, -1.25, -1.6, 1.25, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.6, 1.25, 1.6, 1.25, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.6, 1.25, 1.6, -1.25, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.6, -1.25, -1.6, -1.25, ILayer.MechanicalLayer(23), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.75, -1.35, -1.75, 1.35, eMechanical13, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -1.75, 1.35, 1.75, 1.35, eMechanical13, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 1.75, 1.35, 1.75, -1.35, eMechanical13, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 1.75, -1.35, -1.75, -1.35, eMechanical13, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 1.75, -1.35, -1.75, -1.35, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -1.75, 1.35, 1.75, 1.35, eTopOverlay, 0.12, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0.35, 0, -0.35, 0, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -1.95, -1.55, 1.95, -1.55, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 1.95, -1.55, 1.95, -1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 1.95, -1.31, 2.41, -1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.41, -1.31, 2.41, 1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.41, 1.31, 1.95, 1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 1.95, 1.31, 1.95, 1.55, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 1.95, 1.55, -1.95, 1.55, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -1.95, 1.55, -1.95, 1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -1.95, 1.31, -2.41, 1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.41, 1.31, -2.41, -1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.41, -1.31, -1.95, -1.31, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -1.95, -1.31, -1.95, -1.55, eMechanical15, 0.05, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('\\pa-srv0\Общая работа\GORELKIN\!!!_ПРОЕКТЫ\UCP\UCP\LIB\3D\INDM320X250X220L90X200.STEP', false);
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

    CreateComponentINDM320X250X220L90X200N(0);

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
