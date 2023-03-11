classdef PMTIFFDocument
     %PMTIFFDocument For parsing and reading TIFF file content

    
    properties (Access = private)
        
        FileName
        FilePointer
        
        Header
        ImageFileDirectories
         
    end
    
     properties (Access = private)
         
        MetaData
        ImageMap
        
     end


    methods % INITIALIZE:
        
        function obj =                                                          PMTIFFDocument(FileName)
            % PMTIFFDocument
            % takes 1 argument: name of TIFF file
            % parses file upon initialization
            
            fprintf('@Create PMTIFFDocument for file %s.\n', FileName)
            obj.FileName =                                      FileName;
            obj.FilePointer =                                   fopen(FileName,'r','l');
 
            if obj.FilePointer == -1
                return
            end
            
            obj.Header =                                        obj.GetTIFFHeader;
            obj.ImageFileDirectories =                          obj.GetImageFileDirectories;
            
            switch obj.getType
                
                case 'LSM'
                    
                    obj.MetaData =                           obj.ExtractLSMMetaData;
                    obj =                                    obj.filterImageFileDirectoriesByImageSize;
                     LSMObject =                             PMTIFFLSMDocument(...
                                                                size(obj.ImageFileDirectories,1), ...
                                                                obj.MetaData.EntireMovie.NumberOfTimePoints, ...
                                                                obj.MetaData.EntireMovie.NumberOfPlanes ...
                                                                );
                    
                    OrderOfImages =                         LSMObject.getImageOrderMatrix;
                  
                case 'OME'                    

                     myOMEDocument =                       PMTIFFOMEDocument(obj.getImageFileDirectoriesWithCode(270));
                     obj.MetaData =                          myOMEDocument.getMetaData;
                     OrderOfImages =                         myOMEDocument.getImageOrderMatrix;
                     
                otherwise

                     obj.MetaData =                  obj.getMetaDataObject.getMetaDataStructure;   
                    OrderOfImages =                obj.getImageOrderMatrix;
                    
                    
            end
            
                    ImageMapObjects =       cellfun(@(dir,x,y,z) ...
                                                        PMImageMap(obj.getImapeMapStructure(dir,x,y,z)), ...
                                                        obj.ImageFileDirectories, ...
                                                        num2cell(OrderOfImages(:,1)),...
                                                        num2cell(OrderOfImages(:,2)), ...
                                                        num2cell(OrderOfImages(:,3)) ...
                                                        );
                                                      
                   ImageMapCells =                           arrayfun(@(x) x.getCellMatrix, ImageMapObjects, 'UniformOutput', false);                          
                   ListWithAllDirectories =                  vertcat(ImageMapCells{:});

                   obj.ImageMap=                            [PMImageMap().getTitles; ListWithAllDirectories];
                    
                  fclose(obj.FilePointer); 
        end
           
    end
    
    
    methods % GETTERS 
        
        function Type =             getType(obj)

             DirectoryList =                  obj.ImageFileDirectories;
             ContainsLSMInfo=                  max(max(cellfun(@(x) x==34412, DirectoryList{1}(:,1))));    %check first IFD for lsm
             if ContainsLSMInfo 
                 Type = 'LSM';
                 
             elseif obj.isOME%then check whether it is an OME file
                Type = 'OME';
             else
                 Type = 'Default';
                 
             end

         end
       
        function metaData =         getMetaData(obj)
            metaData = obj.MetaData;
         end
          
        function imageMap =         getImageMap(obj)
            imageMap = obj.ImageMap;
        end
        
        function contents =         getImageFileDirectoryContents(obj)
            contents = cellfun(@(x) PMTIFFImageFileDirectory(x).getStructure,  obj.ImageFileDirectories, 'UniformOutput', false);
            
        end
            
        function rawMetaData =      getRawMetaData(obj)            
        
            switch obj.getType
                
                case 'LSM'
                    RowWithLSMData=         cell2mat(obj.ImageFileDirectories{1,1}(:,1)) == 34412;
                    rawMetaData=            obj.ImageFileDirectories{1,1}{RowWithLSMData, 4};
                    
   
                otherwise
                    error('Image type not supported.')
            end
             
        end
        
    end
    
    
    methods % GETTERS: IMAGE-FILE DIRECTORIES
              
        function ContentOfAllImageDescriptionFields = getImageFileDirectoriesWithCode(obj, Code)
             
             DirectoryList =                            obj.ImageFileDirectories;
             MatchingRows =                             cellfun(@(x) find(cell2mat(x(:,1)) == Code), DirectoryList, 'UniformOutput', false);
             RowsToDelete =                             cellfun(@(x) isempty(x), MatchingRows);
             DirectoryList(RowsToDelete) =              [];
             ContentOfAllImageDescriptionFields =        cellfun(@(x) x{cell2mat(x(:,1)) == Code, 4}, DirectoryList, 'UniformOutput', false);
            
            
        end
       
    end
    
    methods (Access = private) % GETTERS
       
         function ISOME =                    isOME(obj)
            
              ContentOfAllImageDescriptionFields =        obj.getImageFileDirectoriesWithCode(270);
                
              if isempty(ContentOfAllImageDescriptionFields)
                  ISOME = false;
                  
              else
                    ContainOMEString =                          cellfun(@(x)  contains(x, 'OME'), ContentOfAllImageDescriptionFields);

                    AllRowsContainOMEString=                    min(ContainOMEString) == 1;
                    if AllRowsContainOMEString
                        ISOME = true;
                    else
                        error('Unsupported TIFF type')
                    end
                  
              end
            
            
        end
        
        
    end
    
    methods (Access = private) % GETTERS: READ TIFF FROM FILE:
        
           function  Header  =               GetTIFFHeader( obj )
            
                % Header Bytes 0 and 1:
                byte_order =                                (fread(obj.FilePointer, 2, '*char'))';
                switch byte_order
                    case 'II'
                        byteOrder =                       'ieee-le'; % little endian;
                    case 'MM'
                        byteOrder =                       'ieee-be'; % big endian
                    otherwise
                        error('Invalid byte order')
                end
                
                % Bytes 2 and 3: must be "42" if TIFF file:
                TIFFVersionNumber =                         fread(obj.FilePointer,1,'uint16', byteOrder);
                assert(TIFFVersionNumber == 42, 'Invalid TIFF version')

                % Bytes 4 to 7: offset of first image file directory (IFD) location:
                offestOfFirstIFD   =                        fread(obj.FilePointer, 1, 'uint32', byteOrder);
                
                Header.byteOrder=                           byteOrder;
                Header.TIFFVersionNumber=                   TIFFVersionNumber;
                Header.offestOfFirstIFD=                    offestOfFirstIFD;

        end
        
    end
    
    methods (Access = private)  % PROCESSING: STRIP ROWS
        
        function stripStartRows =   getStripStartRows(~, RowsPerStrip, TotalRows)
            stripStartRows =  1 : RowsPerStrip :  TotalRows;
            
        end
        
        function EndRows =          getStripEndRows(obj, RowsPerStrip, TotalRows)
            StartRows =     obj.getStripStartRows(RowsPerStrip, TotalRows);
             EndRows = RowsPerStrip : RowsPerStrip :  TotalRows;
                if length(StartRows) == length(EndRows)
                    
                elseif length(StartRows)  == length(EndRows) + 1
                    EndRows(end + 1) = TotalRows;
                else
                    error('Something went wrong.')
                    
                end
                
        end
        
    end
    
    methods (Access = private)  % GETTERS: META-DATA 
        
        function metaDataObject =       getMetaDataObject(obj)
            
            FirstDirectory = PMTIFFImageFileDirectory(obj.ImageFileDirectories{1});
            
            DimensionChannels =             1;
            VoxelSizeZ =                    1;
           
              metaDataObject =           PMMetaData(...
                                                    FirstDirectory.getTotalRows, ...
                                                    FirstDirectory.getTotalColumns, ...
                                                    1, ...
                                                    length(obj.ImageFileDirectories), ...
                                                    DimensionChannels, ...
                                                    FirstDirectory.getXPixelSize, ...
                                                    FirstDirectory.getYPixelSize, ...
                                                    VoxelSizeZ, ...
                                                    1 : length(obj.ImageFileDirectories) ...
                                                );
                                            
                    
            
        end
        
        function MetaData =             ExtractLSMMetaData(obj)
            
                RowWithLSMData=          cell2mat(obj.ImageFileDirectories{1,1}(:,1))==34412;

                lsmData=                 obj.ImageFileDirectories{1,1}{RowWithLSMData, 4};

                metaDataObject =           PMMetaData(...
                                                lsmData.DimensionY, ...
                                                lsmData.DimensionX, ...
                                                lsmData.DimensionZ, ...
                                                lsmData.DimensionTime, ...
                                                lsmData.DimensionChannels, ...
                                                lsmData.VoxelSizeX, ...
                                                lsmData.VoxelSizeY, ...
                                                lsmData.VoxelSizeZ, ...
                                                lsmData.TimeStamp...
                                            );

                MetaData =                  metaDataObject.getMetaDataStructure;

        end
        
        
    end
    
    methods (Access = private)  % GETTERS: IMAGE-FILE DIRECTORIES (DEFAULT TIFF);
        
         function OrderOfImages =            getImageOrderMatrix(obj)
                OrderOfImages(:,1)=           1 : length(obj.ImageFileDirectories);
                OrderOfImages(:,3)=           1;   % channel
                OrderOfImages(:,2)=           1;      % Z;          
        end

        
    end
    
    methods (Access = private)  % GETTERS: IMAGE-FILE DIRECTORIES
        
        function  ListWithIFDs  =                       GetImageFileDirectories(obj)
            %GETIFDDIRECTORIES returns cell vector with all image-file directories;


                 OffsetOfCurrentIFD=                                                    obj.Header.offestOfFirstIFD;
                 byteOrder=                                                             obj.Header.byteOrder;
                 DirectoryIndex=                                                        1;

                while  OffsetOfCurrentIFD ~= 0 % loop while ifd_pos is not 0 (if 0 this indicates that the last IFD of this file has been reached);


                    IFDEntriesOfCurrentDirectory=                                      obj.getIFDEntriesForOffset(OffsetOfCurrentIFD );

                    NumberOfFieldsInCurrentIFD=                                         size(IFDEntriesOfCurrentDirectory,2);

                    OffsetOfCurrentIFD=                                                 IFDEntriesOfCurrentDirectory{1,end, 1};
                    %ListWithIFDs(DirectoryIndex,1:NumberOfFieldsInCurrentIFD, :)=       ListWithIFDs_CurrentDirectory;

                    ListWithIFDs{DirectoryIndex, 1}(1 : NumberOfFieldsInCurrentIFD, :)=       IFDEntriesOfCurrentDirectory;
                    
                    DirectoryIndex=                                                     DirectoryIndex+ 1;

                end

            end

        function  ListWithIFDs_CurrentDirectory  =      getIFDEntriesForOffset(obj, OffsetOfCurrentIFD )
                %IFD_READALLENTRIES Summary of this function goes here
                %   Detailed explanation goes here


                 % move in the file to the next IFD
                 byteOrder =                                                        obj.Header.byteOrder;

                 fseek(obj.FilePointer, OffsetOfCurrentIFD, -1);
                 numberOfFields =                                                   fread(obj.FilePointer, 1, 'uint16', byteOrder);

                 OffsetsOfIndividualFields=                                         ( (OffsetOfCurrentIFD + 2) : 12 : OffsetOfCurrentIFD + 12 * (numberOfFields - 1) + 2 )';
                 DirectoryIndex=                                                        1;

                 ListWithIFDs_CurrentDirectory{DirectoryIndex, 1, 1}=                numberOfFields;

                 for FieldIndex = 1 : numberOfFields


                    %% read current IFD Entry:
                    % Each 12-byte IFD entry has the following format:

                    % Bytes 0-1: The Tag that identifies the field.
                    % Bytes 2-3: The field Type.
                    % Bytes 4-7: The number of values, Count of the indicated Type.
                    % Bytes 8-11: The value or the offset of the value.

                    OffSetOfField=                  OffsetsOfIndividualFields(FieldIndex);
                    [ FieldContents] =              obj.ReadIFDField(OffSetOfField );

                    Tag=                            FieldContents.Tag;
                    FieldType=                      FieldContents.FieldType;
                    Count=                          FieldContents.Count;
                    Value=                          FieldContents.Value;
                    OffsetOfFieldValue=             FieldContents.OffsetOfValue;


                    %% collect field-contents ;

                    % move to offset after all fields of current IFD:
                    % this shows offset of next IFD:
                    % if this value is zero, this indicates that the current IFD is the last IFD in this file;

                    ListWithIFDs_CurrentDirectory{DirectoryIndex, FieldIndex + 1, 1}=                   Tag;
                    % field offsets are not written into file: they follow from offset and "count" of current IFD;

                    ListWithIFDs_CurrentDirectory{DirectoryIndex, FieldIndex + 1, 2}=                   FieldType;

                    ListWithIFDs_CurrentDirectory{DirectoryIndex, FieldIndex + 1, 3}=                   Count;
                    ListWithIFDs_CurrentDirectory{DirectoryIndex, FieldIndex + 1, 4}=                   Value;
                    ListWithIFDs_CurrentDirectory{DirectoryIndex, FieldIndex + 1, 5}=                   OffsetOfFieldValue;

                 end

                OffSetForOffsetOfNextIFD=                                                   OffsetOfCurrentIFD + 12 * numberOfFields + 2;
                fseek(obj.FilePointer, OffSetForOffsetOfNextIFD, -1);
                OffsetOfCurrentIFD =                                                        fread(obj.FilePointer, 1, 'uint32', byteOrder);

                ListWithIFDs_CurrentDirectory{DirectoryIndex,numberOfFields+2, 1}=          OffsetOfCurrentIFD;


        end

        function  FieldContents  =                      ReadIFDField(obj, OffSetOfField )
            %READIFDFIELD read TIFF image file directory:
            %   Detailed explanation goes here
           byteOrder = obj.Header.byteOrder;
            fseek(obj.FilePointer, OffSetOfField, -1);
            % Bytes 0-1 of field (tag):
            Tag =                                           fread(obj.FilePointer, 1, 'uint16', byteOrder);

            % Bytes 2-3 of field (type)
            FieldType =                                     fread(obj.FilePointer, 1, 'uint16', byteOrder);

            % Bytes 4-7 of field (length/count)
            Count      =                                    fread(obj.FilePointer, 1, 'uint32', byteOrder);

            % get value and/or offset:
            OffSetForReadingField=                          OffSetOfField+8;
            [ Value, OffsetOfFieldValue] =                  IFD_GetValue( obj, OffSetForReadingField, Tag, FieldType, Count);

            % collect field-contents ;
            FieldContents.Tag=                              Tag;
            FieldContents.FieldType=                        FieldType;
            FieldContents.Count=                            Count;
            FieldContents.Value=                            Value;
            FieldContents.OffsetOfValue=                    OffsetOfFieldValue;
        end

        function [ Value, OffsetOfFieldValue] =         IFD_GetValue( obj, OffSetForReadingField, Tag, FieldType, Count)
            %IFD_GETVALUE read value of current IFD
                byteOrder = obj.Header.byteOrder;
                fileID = obj.FilePointer;

            switch (FieldType)

                case 1 %byte
                    NumberOfBytes=      1;
                    MatLabType=         'uint8';

                case 2 %ascii string
                    NumberOfBytes=      1;
                    MatLabType=         'uchar';

                case 3 % word
                    NumberOfBytes=      2;
                    MatLabType=         'uint16';

                case 4 %dword/uword
                    NumberOfBytes=      4;
                    MatLabType=         'uint32';

                case 5 % rational
                    NumberOfBytes=      8;
                    MatLabType=         'uint32';

                case 7
                    NumberOfBytes=      1;
                    MatLabType=         'uchar';

                case 11
                    NumberOfBytes=      4;
                    MatLabType=         'float32';

                case 12
                    NumberOfBytes=      8;
                    MatLabType=         'float64';

                otherwise
                    OffsetOfFieldValue=         NaN;  
                    Value =                     '';
                    return
                     
            end


             % read bytes 8-11 
             fseek(fileID, OffSetForReadingField, -1);
            if NumberOfBytes * Count <= 4 % if the value "fits" into the field: read value (in this case: offset is not relevant)

                 Value =                        fread(fileID, Count, MatLabType, byteOrder);
                 OffsetOfFieldValue=            NaN;  
                 

            else % if the value does not fit: read two times: first the "value" which acutally represents the offset of the value:
                %read two times: first offset of field, then actual value (at
                %indicated offset)

                % if the value is larger than 4 bytes
                % in that case bytes 8 to 11 contain the offset for the value:
                % read and reset offset
                % next field contains an offset:

                OffsetOfFieldValue =                fread(fileID, 1, 'uint32', byteOrder);

                % go to offset position and read value:
                fseek(fileID, OffsetOfFieldValue, -1);


                if Tag == 33629         % metamorph stack plane specifications
                    Value =                         fread(fileID, 6*Count, MatLabType, byteOrder);

                elseif Tag == 34412     %TIF_CZ_LSMINFO
                    TIF.fileID=                     fileID;
                    TIF.BOS=                        byteOrder;  
                    Value =                         readLSMinfo(obj,TIF);

                else

                    if FieldType == 5   % TIFF 'rational' type
                        val =                       fread(fileID, 2*Count, MatLabType, byteOrder);
                        Value=                     [val(1) val(1)];

                    else

                        if ( FieldType == 2 )
                            fseek(fileID, OffsetOfFieldValue, -1);
                            Value =                        fread(fileID, Count, 'uint8', byteOrder);

                        else
                            fseek(fileID, OffsetOfFieldValue, -1);
                            Value =                        fread(fileID, Count, MatLabType, byteOrder);

                        end


                    end

                end

            end

            if ( FieldType == 2 )
                Value =                         char(Value');
            end

        end
        
        function R =                                    readLSMinfo(~,TIF)

            % Read part of the LSM info table version 2
            % this provides only very partial information, since the offset indicate that
            % additional data is stored in the file

            R.MagicNumber          =        sprintf('0x%09X',fread(TIF.fileID, 1, 'uint32', TIF.BOS));

            R.StructureSize        =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);

            R.DimensionX           =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.DimensionY           =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.DimensionZ           =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.DimensionChannels    =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.DimensionTime        =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.IntensityDataType    =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.ThumbnailX           =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.ThumbnailY           =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);


            R.VoxelSizeX           =        fread(TIF.fileID, 1, 'float64', TIF.BOS);
            R.VoxelSizeY           =        fread(TIF.fileID, 1, 'float64', TIF.BOS);
            R.VoxelSizeZ           =        fread(TIF.fileID, 1, 'float64', TIF.BOS);
            R.OriginX              =        fread(TIF.fileID, 1, 'float64', TIF.BOS);
            R.OriginY              =        fread(TIF.fileID, 1, 'float64', TIF.BOS);
            R.OriginZ              =        fread(TIF.fileID, 1, 'float64', TIF.BOS);

            R.ScanType             =        fread(TIF.fileID, 1, 'uint16', TIF.BOS);
            R.SpectralScan         =        fread(TIF.fileID, 1, 'uint16', TIF.BOS);

            R.DataType             =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetVectorOverlay  =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetInputLut       =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetOutputLut      =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetChannelColors  =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);

            R.TimeInterval         =        fread(TIF.fileID, 1, 'float64', TIF.BOS);

            R.OffsetChannelDataTypes =      fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetScanInformatio =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetKsData         =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetTimeStamps     =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetEventList      =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetRoi            =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetBleachRoi      =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);
            R.OffsetNextRecording  =        fread(TIF.fileID, 1, 'uint32', TIF.BOS);

            % There is more information stored in this table, which is skipped here

            %read real acquisition times:
            if ( R.OffsetTimeStamps > 0 )

            status =  fseek(TIF.fileID, R.OffsetTimeStamps, -1);
            if status == -1
                warning('tiffread:TimeStamps', 'Could not locate LSM TimeStamps');
                return;
            end

            StructureSize          = fread(TIF.fileID, 1, 'int32', TIF.BOS);
            NumberTimeStamps       = fread(TIF.fileID, 1, 'int32', TIF.BOS);
            for i=1:NumberTimeStamps
                R.TimeStamp(i,1)     = fread(TIF.fileID, 1, 'float64', TIF.BOS);
            end

            %calculate elapsed time from first acquisition:
            R.TimeOffset = R.TimeStamp - R.TimeStamp(1,1);

            end

            % anything else assigned to S is discarded

         end



        
    end
    
    methods (Access = private)  % SETTERS ImageFileDirectories;
        
        function obj = filterImageFileDirectoriesByImageSize(obj)
            
            DimensionX=              obj.MetaData.EntireMovie.NumberOfRows;
            DimensionY=              obj.MetaData.EntireMovie.NumberOfColumns;
            [obj] =                  obj.TIFF_KeepOnlySizedImages(DimensionX, DimensionY);

        end
        
        function [obj] =                        TIFF_KeepOnlySizedImages(obj, DimensionX, DimensionY)
            
            IFD =                                               obj.ImageFileDirectories;
            
            %% remove all IFD rows with size that does match general movie size (thumbnails etc.);
            ListWithWidth =                                     cell2mat(cellfun(@(x) x(cell2mat(x(:,1))==256,4), IFD));
            ListWithHeight =                                    cell2mat(cellfun(@(x) x(cell2mat(x(:,1))==257,4), IFD));
            RowsWithMaximumWidth=                               ListWithWidth==DimensionX;
            RowsWithMaximumColumn=                              ListWithHeight==DimensionY;
            RowAndColumnWidthCorrect=                           min([RowsWithMaximumWidth RowsWithMaximumColumn], [], 2);
            IFD(~RowAndColumnWidthCorrect,:,:)=                 [];
            obj.ImageFileDirectories =                          IFD;
        end
        
        
        function obj = removeImageDirectoriesWithSizeOne(obj)
            
             IFD =                                               obj.ImageFileDirectories;
              ListWithWidth =                                     cell2mat(cellfun(@(x) x(cell2mat(x(:,1))==256,4), IFD));
            ListWithHeight =                                    cell2mat(cellfun(@(x) x(cell2mat(x(:,1))==257,4), IFD));
            RowsWithMaximumWidth=                               ListWithWidth== 1;
            RowsWithMaximumColumn=                              ListWithHeight== 1;
            RowsToDelete=                           min([RowsWithMaximumWidth RowsWithMaximumColumn], [], 2);
            IFD(RowsToDelete,:,:)=                 [];
            obj.ImageFileDirectories =                          IFD;
            
        end
        
        
    end

    methods (Access = private)  % GETTERS: IMAGEMAP
   
        function FieldsForImageReading =    getImapeMapStructure(obj, CurrentImageFileDirectory, FrameNumber, PlaneNumber, varargin)
            
            if length(varargin) == 1
                ChannelNumber = varargin{1};
            end
            
            MyImageFileDirectory =              PMTIFFImageFileDirectory(CurrentImageFileDirectory);
            
             MyTargetChannelIndex =                   MyImageFileDirectory.getTargetChannels;
             if isnan(MyTargetChannelIndex)
                    assert(isnumeric(ChannelNumber) && isscalar(ChannelNumber) && ~isnan(ChannelNumber), 'Wrong channel number.')
                    MyTargetChannelIndex=                       ChannelNumber;
                 
             end
             
                FieldsForImageReading.ListWithStripOffsets(:,1)=            MyImageFileDirectory.getStripOffsets;
                FieldsForImageReading.ListWithStripByteCounts(:,1)=         MyImageFileDirectory.getStripByteCounts;

                FieldsForImageReading.FilePointer =                         obj.FilePointer;
                FieldsForImageReading.ByteOrder =                           obj.Header.byteOrder;

                FieldsForImageReading.BitsPerSample=                        MyImageFileDirectory.getBitsPerSample;

                FieldsForImageReading.Precisision =                         MyImageFileDirectory.getPrecision;
                FieldsForImageReading.SamplesPerPixel =                     MyImageFileDirectory.getSamplesPerPixel;

                FieldsForImageReading.TotalColumnsOfImage=                  MyImageFileDirectory.getTotalColumns;
                FieldsForImageReading.TotalRowsOfImage=                     MyImageFileDirectory.getTotalRows;

                FieldsForImageReading.TargetFrameNumber =                   FrameNumber;
                FieldsForImageReading.TargetPlaneNumber =                   PlaneNumber;

                FieldsForImageReading.RowsPerStrip =                        MyImageFileDirectory.getRowsPerStrip; 
                
                FieldsForImageReading.TargetStartRows(:,1)=                 obj.getStripStartRows(MyImageFileDirectory.getRowsPerStrip, MyImageFileDirectory.getTotalRows);          
                FieldsForImageReading.TargetEndRows(:,1)=                   obj.getStripEndRows(MyImageFileDirectory.getRowsPerStrip, MyImageFileDirectory.getTotalRows);
                FieldsForImageReading.TargetChannelIndex=                   MyTargetChannelIndex;

                FieldsForImageReading.PlanarConfiguration=                  MyImageFileDirectory.getPlanarConfiguration;
                FieldsForImageReading.Compression=                          MyImageFileDirectory.getCompressionType;

             
        end
         
    end
    
    methods  % GETTERS: FILE-MANAGEMENT
        
        function value =        getFileCouldBeAccessed(obj)
            value =         obj.getPointer ~= -1;
        end
        
        function pointer =      getPointer(obj)
            pointer = fopen(obj.FileName,'r','l');
            
        end 
        
        
    end
    
end
    
