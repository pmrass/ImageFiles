classdef PMImageBioRadPicFile
    %PMIMAGEBIORADPICFILE to create MetaData and ImageMap of .pic file
    
    
%     Copyright (c) 2007, Phil Larimer
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.


    properties (Access = private)
        
        FileName 
        PicFolderObject
        
        TimeStampText
        
    end
    
    properties (Access = private)
        
        PicMetaData
        CollectedNotes
        
        MetaData
        ImageMap
        
    end
    
    properties (Constant, Access = private)
       
        HEADER_LEN  =           76;
        NOTE_LEN    =           96;

        NOTE_TYPE_LIVE = 1;         % Information about live collection
        NOTE_TYPE_FILE1 = 2;        % Note from image #1					
        NOTE_TYPE_NUMBER = 3;       % Number in multiple image file		
        NOTE_TYPE_USER = 4;         % User notes generated notes			
        NOTE_TYPE_LINE = 5;         % Line mode info						
        NOTE_TYPE_COLLECT = 6;      % Collect mode info					
        NOTE_TYPE_FILE2 = 7;        % Note from image #2					
        NOTE_TYPE_SCALEBAR = 8;     % Scale bar info						
        NOTE_TYPE_MERGE = 9;        % Merge Info							
        NOTE_TYPE_THRUVIEW = 10;    % Thruview Info							
        NOTE_TYPE_ARROW = 11;       % Arrow info								
        NOTE_TYPE_VARIABLE = 20;    % Again internal variable ,except held as  
        NOTE_TYPE_STRUCTURE = 21;   % a structure.

        AXT_D = 1;                  % distance in microns  		
        AXT_T = 2;                  % time in sec					
        AXT_A = 3;                  % angle in degrees				
        AXT_I = 4;                  % intensity in grey levels		
        AXT_M4 = 5;                 % 4-bit merged image			
        AXT_R = 6;                  % Ratio						
        AXT_LR = 7;                 % Log Ratio					
        AXT_P = 8;                  % Product						
        AXT_C = 9;                  % Calibrated					
        AXT_PHOTON = 10;			% intensity in photons/sec		
        AXT_RGB = 11;               % RGB type                     
        AXT_SEQ = 12;               % SEQ type (eg 'experiments')	
        AXT_6D = 13;                % 6th level of axis			
        AXT_TC = 14;				% Time Course axis				
        AXT_S = 15;                 % Intensity signoid cal		
        AXT_LS = 16;				% Intensity log signoid cal	
        AXT_BASE = base2dec('FF', 16);	% mask for axis TYPE			
        AXT_XY = base2dec('100', 16);	% axis is XY, needs updating by LENS 
        AXT_WORD = base2dec('200', 16);  % axis is word. only corresponds to axis[0] 
 
    end
    
    methods
        
        function obj = PMImageBioRadPicFile(varargin)
            %PMIMAGEBIORADPICFILE Construct an instance of this class
            %   takes 1 argument:
            % 1: character string of entire .pic path
            
            switch length(varargin)
               
                case 1
                    assert(ischar(varargin{1}), 'Wrong input.')
                     obj.FileName =                  varargin{1};
                     assert(obj.getFileCouldBeAccessed, 'File could not be accessed.')
                     
                otherwise
                    error('Wrong input.')
                
            end
            
            fprintf('@Create PMImageBioRadPicFile for file %s.\n', obj.FileName)
            
            ParentFolder  =               fileparts(obj.FileName);
            obj.PicFolderObject =         PMImageBioRadPicFolder(ParentFolder);

            obj =                         obj.setPicMetaData;
            obj.TimeStampText =           obj.getTimeStampTextFromFile;
         
            imageMapObj =                 PMImageMap(obj.getImageMapStructure);   
            obj.ImageMap =                [imageMapObj.getTitles; imageMapObj.getCellMatrix];
            
            obj.MetaData =                obj.getMetaDataFromFile;
            
        end
        
       
        
    
        
    end
    
    methods % GETTER
       
        function metaData =     getMetaData(obj)
            metaData = obj.MetaData;
        end
        
        function imageMap =     getImageMap(obj)
            imageMap = obj.ImageMap;
        end
        
    end
    
    methods % GETTERS FILE-MANAGEMENT:
       
        function value = getFileCouldBeAccessed(obj)
              pointer = fopen(obj.FileName,'r','l'); 
            value =         pointer ~= -1;
        end
        
    end
    

    methods % GETTERS FRAMENUMBERS
        
        function number =           getTotalFrameNumbersInFolder(obj)
            % GETTOTALFRAMENUMBERSINFOLDER
            % returns maximum frame number in linked folder (maybe move to PMImageBioRadPicFolder?);
            number = max(obj.getFrameNumbersOfAllFiles);  
        end
            
        function channelCodes =     getFrameNumbersOfAllFiles(obj)
            myFileNameList =        obj.PicFolderObject.getFileNames;
            channelCodes =          cellfun(@(x) obj.extractFrameNumberFromFileName(x), myFileNameList);
        end

        function channelCode =      extractFrameNumberFromFileName(obj, FileName)
            [~,b,c] =                   fileparts( FileName);
            name =                      [b c];
            channelCode=                str2double(name(1, end - 8 : end - 6));
        end
  
    end
    
    
    
    methods (Access = private) % GETTERS IMAGEMAP-STRUCTURE
        
        function FieldsForImageReading =      getImageMapStructure(obj)
            
                assert(strcmp( obj.PicMetaData.ColorType, 'grayscale') && obj.PicMetaData.BitDepth == 8, 'Data format not supported')

                NumberOfPlanes =                                        obj.PicMetaData.NumImages; % number of images equals number of planes
                  
                FieldsForImageReading.ListWithStripOffsets(:,1)=            76;
                FieldsForImageReading.ListWithStripByteCounts(:,1)=         obj.PicMetaData.Height * obj.PicMetaData.Width * NumberOfPlanes;

                FieldsForImageReading.FilePointer =                         '';
                FieldsForImageReading.ByteOrder =                           'ieee-le';

                FieldsForImageReading.BitsPerSample=                        obj.PicMetaData.BitDepth;

                FieldsForImageReading.Precisision =                         'uint8';
                FieldsForImageReading.SamplesPerPixel =                     1;

                FieldsForImageReading.TotalColumnsOfImage=                  obj.PicMetaData.Width;
                FieldsForImageReading.TotalRowsOfImage=                     obj.PicMetaData.Height;

                FieldsForImageReading.TargetFrameNumber =                   1;
                FieldsForImageReading.TargetPlaneNumber =                   1 : NumberOfPlanes;

                FieldsForImageReading.RowsPerStrip =                        obj.PicMetaData.Height; 
                
                FieldsForImageReading.TargetStartRows(:,1)=                1;          
                FieldsForImageReading.TargetEndRows(:,1)=                  obj.PicMetaData.Height;
                FieldsForImageReading.TargetChannelIndex=                   obj.extractChannelNumberFromFileName(obj.FileName);

                FieldsForImageReading.PlanarConfiguration=                  NaN;
                FieldsForImageReading.Compression=                          'NoCompression';

              

          end
          
    end
    
    methods % GETTERS: TIMESTAMP-TEXT
       
         function TimeStampText =                getTimeStampTextFromFile(obj)
              
                CompleteFileNameMetaData=               strcat(obj.PicFolderObject.getFolderName, '/lse.xml');
                assert(exist(CompleteFileNameMetaData, 'file')==2, 'Meta data missing!')
                TimeStampText=                          fileread(CompleteFileNameMetaData);
 
          end
       
        
    end
    
    
    methods (Access = private)
      
        function ImageSequenceOfCurrentFile =   readpic(obj, filename)
            % read in a Biorad .pic image file
            % image = readpic(filename)

            % adapted from:
            % http://www.bu.edu/cism/cismdx/ref/dx.Samples/util/biorad-pic/PIC2dx.c
            % http://rsb.info.nih.gov/ij/plugins/download/Biorad_Reader.java


            ImageWidth=                                     obj.PicMetaData.Width;
            ImageHeight=                                    obj.PicMetaData.Height;
            NumberOfReads=                                  obj.PicMetaData.NumImages;
            BithDepth=                                      ['uint' sprintf('%0.0f', obj.PicMetaData.BitDepth)];

            fid =                                           fopen(filename, 'r');

            % skip over the header
            fseek(fid, 76, 'bof');

            % read data: one image is located just after each other;
            ImageSequenceOfCurrentFile =                zeros(ImageWidth, ImageHeight, NumberOfReads);        
            for x = 1:NumberOfReads
                CurrentImage=                           fliplr(fread(fid, [ImageWidth, ImageHeight], BithDepth));
                ImageSequenceOfCurrentFile(:,:,x) =     CurrentImage;


            end

            fclose(fid);

        end

    end
    
    methods (Access = private) % SETTERS: setPicMetaData
       
        function obj =          setPicMetaData(obj)
            % adapted from:
            % http://www.bu.edu/cism/cismdx/ref/dx.Samples/util/biorad-pic/PIC2dx.c
            % http://rsb.info.nih.gov/ij/plugins/download/Biorad_Reader.java


            % read header
            fid = fopen(obj.FileName, 'r');

            if fid ~= -1
                % Initialize universal structure fields to fix the order
                obj.PicMetaData.Filename =          '';
                obj.PicMetaData.FileModDate =       [];
                obj.PicMetaData.FileSize =          [];
                obj.PicMetaData.Format =            'pic';
                obj.PicMetaData.FormatVersion =     [];
                obj.PicMetaData.Width =             [];
                obj.PicMetaData.Height =            [];
                obj.PicMetaData.BitDepth =          [];
                obj.PicMetaData.ColorType =         'grayscale';
                obj.FileName =                      fopen(fid);  % Get the full path name if not in pwd

                d =                                 dir(obj.FileName);      % Read directory information
                obj.PicMetaData.Filename =          obj.FileName;
                obj.PicMetaData.FileModDate =       d.date;
                obj.PicMetaData.FileSize =          d.bytes;

                % check to make sure that the file isn't zero length
                fseek(fid, 0, 'eof');   
                endOfFile = ftell(fid);

                if endOfFile > obj.HEADER_LEN
                    % read header
                    fseek(fid, 0, 'bof');
                    obj.PicMetaData.Width =             fread(fid, 1, 'int16');
                    obj.PicMetaData.Height =            fread(fid, 1, 'int16');
                    obj.PicMetaData.NumImages =         fread(fid, 1, 'int16');
                    obj.PicMetaData.Ramp1 =             fread(fid, 2, 'int16');
                    obj.PicMetaData.Notes =             fread(fid, 1, 'int32');
                    byteFormat =                        fread(fid, 1, 'int16');
                    obj.PicMetaData.ImageNumber =       fread(fid, 1, 'int16');
                    fread(fid, 32, 'char');
                    if fread(fid, 1, 'int16')
                        % merged format is not currently supported
                        obj.PicMetaData = [];
                        return
                    end

                    obj.PicMetaData.ColorStatus1 =      fread(fid, 1, 'int16');
                    if fread(fid, 1, 'int16') ~= 12345
                        obj.PicMetaData = [];
                        return
                    end

                    obj.PicMetaData.Ramp2 =             fread(fid, 2, 'int16');
                    obj.PicMetaData.ColorStatus2 =      fread(fid, 1, 'int16');
                    obj.PicMetaData.IsEdited =          fread(fid, 1, 'int16');
                    obj.PicMetaData.LensMagnification = fread(fid, 1, 'int16');
                    obj.PicMetaData.LensFactor =        fread(fid, 1, 'float32');
                    fread(fid, 3, 'int16');

                    if byteFormat == 1
                        obj.PicMetaData.BitDepth = 8;
                    else
                        obj.PicMetaData.BitDepth = 16;
                    end

                    % read notes
                    fseek(fid, obj.PicMetaData.Width * obj.PicMetaData.Height * obj.PicMetaData.NumImages * obj.PicMetaData.BitDepth / 8, 'cof');
                    notesOffset = ftell(fid);
                    obj = obj.setAxisInfo(fid, notesOffset, endOfFile);
                    fclose(fid);
                else
                    obj.PicMetaData = []; %tell calling subroutine that the file was zero length

                end

            else
                obj.PicMetaData = []; %tell calling subroutine that no file was found

            end





        end

        function obj =          setAxisInfo(obj, fid, notesOffset, endOfFile)
                % read all of the notes
                fseek(fid, notesOffset, 'bof');
                noteIndex = 1;

                while notesOffset + obj.NOTE_LEN * (noteIndex - 1) <= endOfFile
                    obj.PicMetaData.Note{noteIndex} = obj.readNote(fid,notesOffset,  noteIndex);

                    if obj.PicMetaData.Note{noteIndex}.type == obj.NOTE_TYPE_VARIABLE

                        if strfind(obj.PicMetaData.Note{noteIndex}.text, 'AXIS_2') == 1
                            % horizontal axis
                            tempData = sscanf(obj.PicMetaData.Note{noteIndex}.text(7:end), ' %d %g %g %s');
                            axisType = tempData(1);
                            if axisType == obj.AXT_D
                                obj.PicMetaData.Origin(1) = tempData(2);
                                obj.PicMetaData.Delta(1) = tempData(3);
                            end
                            obj.PicMetaData.Units{1} = char(tempData(4:end)');

                        elseif strfind(obj.PicMetaData.Note{noteIndex}.text, 'AXIS_3') == 1
                            % vertical axis
                            tempData = sscanf(obj.PicMetaData.Note{noteIndex}.text(7:end), ' %d %g %g %s');
                            axisType = tempData(1);
                            if axisType == obj.AXT_D
                                obj.PicMetaData.Origin(2) = tempData(2);
                                obj.PicMetaData.Delta(2) = tempData(3);
                            end
                            obj.PicMetaData.Units{2} = char(tempData(4:end)');

                        elseif strfind(obj.PicMetaData.Note{noteIndex}.text, 'AXIS_4') == 1
                            % z axis
                            axisType = sscanf(obj.PicMetaData.Note{noteIndex}.text(7:end), ' %d');
                            if axisType == obj.AXT_D
                                tempData = sscanf(obj.PicMetaData.Note{noteIndex}.text(7:end), ' %d %g %g %s');
                                obj.PicMetaData.Origin(3) = tempData(2);
                                obj.PicMetaData.Delta(3) = tempData(3);
                            end
                            obj.PicMetaData.Units{3} = char(tempData(4:end)');    

                        elseif strfind(obj.PicMetaData.Note{noteIndex}.text, 'AXIS_9') == 1
                            tempData = sscanf(obj.PicMetaData.Note{noteIndex}.text(7:end), ' %d %g %g %s');
                            axisType = tempData(1);
                            if axisType == obj.AXT_RGB
                                obj.PicMetaData.Origin(4) = tempData(2);
                                obj.PicMetaData.Delta(4) = tempData(3);
                                obj.PicMetaData.Units{4} = char(tempData(4:end)');
                            end

                        elseif strfind(obj.PicMetaData.Note{noteIndex}.text, 'INFO_FRAME_RATE') == 1
                            obj.PicMetaData.FramesPerSecond = sscanf(obj.PicMetaData.Note{noteIndex}.text(14:end), ' %d');

                        elseif strfind(obj.PicMetaData.Note{noteIndex}.text, 'INFO_OBJECTIVE_NAME = ') == 1
                            obj.PicMetaData.Objective = obj.PicMetaData.Note{noteIndex}.text(23:end);
                            obj.PicMetaData.Objective = obj.PicMetaData.Objective(obj.PicMetaData.Objective ~= char(0));

                        elseif strfind(obj.PicMetaData.Note{noteIndex}.text, 'PIC_FF_VERSION = ') == 1
                            obj.PicMetaData.FormatVersion = str2double(obj.PicMetaData.Note{noteIndex}.text(18:end));

                        else
                            % add any note you care about here

                        end
                    else
                        % add info about other note types here

                    end
                    noteIndex = noteIndex + 1;
                end
        end

        function note =         readNote(obj, fid, notesOffset, index)
                fseek(fid, notesOffset + (index - 1) * obj.NOTE_LEN, 'bof');
                note.level = fread(fid, 1, 'int16');
                note.next = fread(fid, 1, 'int32');
                note.num = fread(fid, 1, 'int16');
                note.status = fread(fid, 1, 'int16');
                note.type = fread(fid, 1, 'int16');
                note.x = fread(fid, 1, 'int16');
                note.y = fread(fid, 1, 'int16');
                note.text = char(fread(fid, 80, 'char')');
        end

                
        
    end
    
    methods (Access = private) % GETTERS META-DATA
       
           function MetaData =      getMetaDataFromFile(obj)
              
                MetaData.EntireMovie.NumberOfRows=                     obj.PicMetaData.Height; 
                MetaData.EntireMovie.NumberOfColumns=                  obj.PicMetaData.Width; 
                MetaData.EntireMovie.NumberOfPlanes=                   obj.PicMetaData.NumImages; 
                MetaData.EntireMovie.NumberOfTimePoints=               1; % this is for current file only: after combining multiple files this number will be adjusted accordingly
                MetaData.EntireMovie.NumberOfChannels=                 max(obj.getChannelNumbersOfAllFiles); 

                MetaData.EntireMovie.VoxelSizeX=                       obj.getPixelSize( 'AXIS_2'); 
                MetaData.EntireMovie.VoxelSizeY=                       obj.getPixelSize( 'AXIS_3');
                MetaData.EntireMovie.VoxelSizeZ=                       obj.getPixelSize( 'AXIS_4');

                TimeFrame =                             obj.extractFrameNumberFromFileName(obj.FileName);
                CaptureTime =                           obj.getCaptureTimeForFrame(TimeFrame);
               
                AbsoluteTime =                          obj.getStartTime + CaptureTime;
                MetaData.TimeStamp =                    AbsoluteTime;

                MetaData.RelativeTimeStamp =            MetaData.TimeStamp- MetaData.TimeStamp(1);

           
              
          end
          
           function PixelSize =     getPixelSize(obj, Code) % for extracting pixel size
                  
                    MyNotes =               obj.getPicMetaDataNotes;

                    Index =                 cellfun(@(x) contains(x, Code), MyNotes);
                    XData =                 MyNotes{Index,1};
                    XData =                 split(XData);
                    PixelSize =             str2double(XData{4})*1e-6;

           end
              
           function MyNotes =       getPicMetaDataNotes(obj)
               MyNotes =               (cellfun(@(x) x.text, obj.PicMetaData.Note, 'UniformOutput', false))';
           end
           
    end
    
    methods (Access = private) % GETTERS CAPTURE TIMES
       
          function StartTime_Seconds =      getStartTime(obj)
              
                StartIndex=                         strfind( obj.TimeStampText, '<CreationDate>');
                StartIndex=                         StartIndex(1) + length('<CreationDate>') - 1;
                CreationDateString=                 obj.TimeStampText(StartIndex + 1 : StartIndex + 19);

                DaysAfterAD_ExperimentStart=        datenum(CreationDateString(1 : 10),'yyyy-mm-dd');
                StartOfExperiment_Seconds=          obj.ConvertHourMinuteSecondsToSeconds(CreationDateString(12 : end));
                StartTime_Seconds=                  StartOfExperiment_Seconds + DaysAfterAD_ExperimentStart * 24 * 60 * 60;

              
          end
          
          function Seconds  =               ConvertHourMinuteSecondsToSeconds(~, String )
                %CONVERTHOURMINUTESECONDSTOSECONDS 

                    SecondsFromHours =      str2double(String(1:2)) * 60 * 60;
                    
                    SecondsFromMinutes =    str2double(String(4:5)) * 60;
                    
                    SecondsFromSeconds =    str2double(String(7:8));

                    Seconds =               SecondsFromHours+ SecondsFromMinutes+SecondsFromSeconds;

           end
          
          function TimeCapture_Seconds =    getCaptureTimeForFrame(obj,FrameNumber)
              
              QueryText =                           sprintf('<T Section="%i"', FrameNumber-1);
              StartIndex_WantedTPosition=           strfind( obj.TimeStampText, QueryText);
              TextSection =                         obj.TimeStampText(StartIndex_WantedTPosition : end);

              QueryText =                           strfind(TextSection, 'TimeCompleted="');
              StartIndex_CompletedTime =            QueryText(1) + length('TimeCompleted="');
              TextStartinAtWantedTime =             TextSection(StartIndex_CompletedTime  : end);
              
              EndIndicesCompleteTimes =             strfind(TextStartinAtWantedTime, '"');
              EndIndexCompletedTime =               EndIndicesCompleteTimes(1);
              TimeCaptureString =                   TextStartinAtWantedTime(1 : EndIndexCompletedTime - 1);
              
              TimeCapture_Seconds =                 str2double(TimeCaptureString);
          end
         
    end
    
     methods (Access = private) % GETTERS CHANNELNUMBERS
       
           function channelCodes =      getChannelNumbersOfAllFiles(obj)
               channelCodes =       cellfun(@(x) obj.extractChannelNumberFromFileName(x), obj.PicFolderObject.getFileNames);
           end
           
           function channelCode =       extractChannelNumberFromFileName(obj, FileName)
                    [~,b,c] =                   fileparts( FileName);
                    name =                      [b c];
                    channelCode=                str2double(name(1,end-5:end-4));
           end
           
     end
     
     methods (Access = private) % CURRENTLY NOT USED
         
         function writepic(obj, X, filename, metadata)
            % write a biorad format file
            % writepic(X, filename, metadata);
            % writepic(X, filename); 

            if nargin < 3
                metadata.Width = size(X, 1);
                metadata.Height = size(X, 2);
                metadata.NumImages = size(X, 3);
                switch class(X)
                    case 'uint8'
                        metadata.BitDepth = 8;
                    case 'uint16'
                        metadata.BitDepth = 16;
                    case {'single', 'double'}
                        metadata.BitDepth = 16;
                        % who know what the scaling is so just spread it over the range
                        X = uint16((X - min(min(min(X)))) / (max(max(max(X))) - min(min(min(X)))) * 2^16);
                    otherwise
                        error('Unsupported class of image data');
                end
                metadata.LensMagnification = 1;
                metadata.LensFactor = 1;
                metadata.Origin = [0 0];
                metadata.Delta = [0 0];
                metadata.Note = {};
            end

            fid = fopen(filename, 'w');

                % write header data
                fwrite(fid, metadata.Width, 'int16');
                fwrite(fid, metadata.Height, 'int16');
                fwrite(fid, metadata.NumImages, 'int16');

                fwrite(fid, [0 255], 'int16');
                fwrite(fid, -1, 'int32');
                if metadata.BitDepth == 8
                    fwrite(fid, [1 0], 'int16');
                else
                    fwrite(fid, [0 0], 'int16');
                end
                tempFileName = filename(find(filename == '\', 1, 'last') + 1:end)';
                fwrite(fid, [tempFileName(1:min([end 32])); zeros(32 - length(tempFileName), 1)], 'char');
                fwrite(fid, [0 7 12345 0 255 7 0], 'int16');
                fwrite(fid, metadata.LensMagnification, 'int16');
                fwrite(fid, metadata.LensFactor, 'int16');
                fwrite(fid, [0 0 0], 'int16');

                % write image data
                fwrite(fid, X, ['uint' sprintf('%0.0f', metadata.BitDepth)]);	

                fwrite(fid, 0, 'int16');

                writeComment(fid, ['PIXEL_BIT_DEPTH = ' metadata.BitDepth])
                writeComment(fid, 'PIC_FF_VERSION = 4.5')

                writeComment(fid, ['AXIS_2 001 ' sprintf('%1.4f',metadata.Origin(1)) ' ' sprintf('%1.4f', metadata.Delta(1)) ' Microns'])
                writeComment(fid, ['AXIS_3 002 ' sprintf('%1.4f',metadata.Origin(2)) ' ' sprintf('%1.4f', metadata.Delta(2)) ' Microns'])

                if isfield(metadata, 'Note')
                    for i = 1:numel(metadata.Note)
                        writeComment(fid, metadata.Note{i}.text);
                    end
                end

                % without this the pic reading software that I have throws an
                % unexpected end of file error
                fwrite(fid, zeros(640, 1), 'char');

            fclose(fid);

            end

         function writeComment(obj, fid, comment)

                fwrite(fid, -1, 'int16');
                fwrite(fid, 1, 'int32');
                fwrite(fid, [0 1 20 0 0],  'int16');

                % pad the comment up to 80 characters
                if numel(comment) > 80
                    % must truncate the comment or the file will be corrupted, but
                    % should never get to here
                    comment = comment(1:80);
                end
                fwrite(fid,  [comment  zeros(1, 80 - length(comment))], 'char');


            % 	http://rsb.info.nih.gov/ij/plugins/download/Biorad_Reader.java
            %   The header of Bio-Rad .PIC files is fixed in size, and is 76 bytes.
            % 
            %   ------------------------------------------------------------------------------
            %   'C' Definition              byte    size    Information
            %   (bytes)   
            %   ------------------------------------------------------------------------------
            %   int nx, ny;                 0       2*2     image width and height in pixels
            %   int npic;                   4       2       number of images in file
            %   int ramp1_min, ramp1_max;   6       2*2     LUT1 ramp min. and max.
            %   NOTE *notes;                10      4       no notes=0; has notes=non zero
            %   BOOL byte_format;           14      2       bytes=TRUE(1); words=FALSE(0)
            %   int n;                      16      2       image number within file
            %   char name[32];              18      32      file name
            %   int merged;                 50      2       merged format
            %   unsigned color1;            52      2       LUT1 color status
            %   unsigned file_id;           54      2       valid .PIC file=12345
            %   int ramp2_min, ramp2_max;   56      2*2     LUT2 ramp min. and max.
            %   unsigned color2;            60      2       LUT2 color status
            %   BOOL edited;                62      2       image has been edited=TRUE(1)
            %   int _lens;                  64      2       Integer part of lens magnification
            %   float mag_factor;           66      4       4 byte real mag. factor (old ver.)
            %   unsigned dummy[3];          70      6       NOT USED (old ver.=real lens mag.)	

         end

         function tf = ispic(obj, filename)
            %ISPIC Returns true for a Biorad PIC file.
            %   TF = ISPIC(FILENAME)

            fid = fopen(filename, 'r');
            if (fid < 0)
                tf = false;
            else
                fseek(fid, 54)
                sig = fread(fid, 1, 'uint16');
                fclose(fid);
                tf = isequal(sig, 12345);
            end

        end
         
     end
     
end

