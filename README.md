# NEF-JPG Pair Manager


_A Bash script for automated management of Nikon photo files._

#### **Key Features**

1.  **File Pair Management**
    
    -   Automatically detects  `.nef`  (RAW) files  **missing corresponding  `.jpg`  counterparts**
        
    -   Moves orphaned  `.nef`  files to an  `unpaired/`  directory
        
2.  **Statistics & Logging**
    
    -   Provides detailed file counts:
        
        -   Total  `.nef`  and  `.jpg`  files
            
        -   Paired (NEF+JPG) and unpaired NEF files
            
    -   Logs all moved files with timestamps to  `unpaired.log`
        
    -   Saves pre-/post-processing stats in  `file_stats.log`
        
3.  **Flexible Options**
    
    -   Recursive directory scanning (`-r`)
        
    -   Dry-run mode (`--dry-run`) for testing
        
    -   Custom log file support (`-l filename`)
        
4.  **Error Handling**
    
    -   Checks write permissions
        
    -   Handles filenames with spaces/special characters
        

#### **Usage**

    ./script.sh [-r|--recursive] [-d|--dry-run] [-l|--log filename]

**Outputs**:

-   Orphaned  `.nef`  files moved to  `unpaired/`
    
-   Detailed console/file reports
    

**Optimized for**:

-   Nikon photographers managing RAW+JPEG libraries
    
-   Identifying "lost" RAW files
    
-   Batch cleanup of photo directories
    

**Requirements**: Bash 4+, standard GNU utilities (`find`, `mv`).

----------

### **Options**

`./unpaired.sh -r|--recursive` - recursive processing (include subdirectories)

`./unpaired.sh -d|--dry-run` - previews changes without any file operations (test)

`./unpaired.sh -l|--log filename` - writing the operation log to the specified file
