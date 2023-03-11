classdef PMImageBioRadPicFolder
    %  PMImageBioRadPicFolder primarily for getting files within pic-folder;
    %   for detailed analysis of files use PMImageBioRadPicFile;
    
    properties (Access = private)
        FolderObject
        FolderName % pic file is a folder that contains files with the actual image information;
        FileNameList
        
    end
    
    methods
        
        function obj = PMImageBioRadPicFolder(FolderName)
            %PMImageBioRadPicFolder Construct an instance of this class
            %   takes 1 argument:
            % 1: character string of name of folder that contains pic-files;
            obj.FolderName=         FolderName;
            obj.FolderObject =      PMFile(FolderName);
            obj =                   obj.setFileNames;
      

        end
        
 
    end
    
    methods % GETTERS
        
        function name = getFolderName(obj)
            name = obj.FolderName;
        end
        
        function list = getFileNames(obj)
           list = obj.FileNameList; 
        end
        
        function pointer = getPointer(obj)
            pointer =                      fopen(obj.FolderName,'r','l'); 
        end
        
        function FilteredFileNames = filterFileNamesByChannel(obj,ChannelCode) 
            StringOfFiles=                          cell2mat(obj.FileNameList(:,1));
            CodeForChannel=                         StringOfFiles(:,end-4:end-4);
            ListWithStringsToErase=                 CodeForChannel == ChannelCode;
            FilteredFileNames =                     obj.FileNameList(ListWithStringsToErase,:);
        end
        
    end
    
    
    methods (Access = private)
       
         function obj =     setFileNames(obj)
            %SETFILENAMES 
                FilesInCurrentDirectory_Matrix =      obj.FolderObject.getFileNamesInDirectory;
                FilesInCurrentDirectory_Matrix =      obj.FolderObject.removeFileNamesWithoutExtension(FilesInCurrentDirectory_Matrix, '.pic');
                obj =                                 obj.verifyFileNames(FilesInCurrentDirectory_Matrix);

                 MyFolderName =                       obj.FolderObject.getFolderName; 
                FileNames =                           cellfun(@(x) [MyFolderName, '/', x], FilesInCurrentDirectory_Matrix, 'UniformOutput', false);                 
                obj.FileNameList =                    FileNames;


         end
        
         function obj =     verifyFileNames(obj, FilesInCurrentDirectory_Matrix)
             
                ShowIfFileNameCharacterIsString_Cell =     isstrprop(FilesInCurrentDirectory_Matrix, 'digit');
                ShowIfFileNameCharacterIsString_Matrix=    cell2mat(ShowIfFileNameCharacterIsString_Cell);
                PositionsForChannelCode=                   ShowIfFileNameCharacterIsString_Matrix(:,end-5:end-4);
                ChannelPositionsAreAllNumerical=           all(PositionsForChannelCode(:));
                assert(ChannelPositionsAreAllNumerical, 'Filename has wrong format! Check source data.')

                 
         end
        
        
    end
    
end

