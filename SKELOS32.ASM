;----------------------------------------------------------------------
; SKELOS32.ASM : OS/2 32-Bit Assembler Skeleton Program
; AUTHOR       : Bill Magaletta (CIS 72411,2473)
; DATE         : September 20, 1992
;
; This program has been written to TASM's IDEAL mode, and probably won't
; assemble correctly using MASM.
;
; CONDITIONS ON ENTRY                                          
;
;
;   CS  DOS       : ?
;       OS2 16-bit: Code segment selector.
;           32-bit: Code selector for the base of the address space.
;
;   SS  DOS       : Stack segment selector, except in TINY model,
;            where SS = CS.
;       OS2 16-bit: Automatic data segment selector.
;           32-bit: Data selector for the base of the address space.
;
;   DS  DOS       : PSP segment selector.
;       OS2 16-bit: Automatic data segment selector.
;           32-bit: Data selector for the base of the address space.
;
;   ES  DOS       : PSP segment selector.
;       OS2 16-bit: 0
;           32-bit: Data selector for the base of the address space.
;
;   FS  DOS       : ?
;       OS2 16-bit: ?
;           32-bit: TIB (Thread Information Block) Data Selector.
;
;   IP  DOS       : Program entry point offset.
;       OS2 16-bit: ditto
;           32-bit: ditto

;   AX  DOS       : ?
;       OS2 16-bit: Environment segment selector. (This selector can   
;            also be obtained via DosGetEnv.)                   
;           32-bit: 0
;
;   BX  DOS       : ?                                                  
;       OS2 16-bit: Offset to program name in environment segment.     
;            (This offset can also be obtained via DosGetEnv.)  
;           32-bit: 0
;
;   CX  DOS       : ?
;       OS2 16-bit: Size of automatic data segment. Zero means 65,536. 
;           32-bit: 0
;
;   DX  DOS       : ?
;       OS2 16-bit: ?
;           32-bit: 0

;
;   SP  DOS       :                                                    
;       OS2 16-bit: Top of stack offset.
;           32-bit: ditto
;
;             [ESP+00] : Return address; EAX should = exit code.
;             [ESP+04] : Program module handle.
;             [ESP+08] : (reserved)
;             [ESP+12] : Environment data object address.
;             [ESP+16] : Address of cmd line in env data object.
;
;
;   BP  DOS       : ?                                                  
;       OS2 16-bit: 0
;           32-bit: 0
;
;   other         : All other registers are undefined.
;
;----------------------------------------------------------------------

         IDEAL
         P386
         MODEL OS2 USE32 FLAT
         LARGESTACK
         STACK 8192H

         extrn  syscall Dos32PutMessage:near
         extrn  syscall Dos32Write:near


;----------------------------------------------------------------------
; DATA
;----------------------------------------------------------------------

         DATASEG

Msg1     DB    13,10
         DB    'OS/2 Linear Executable (32-Bit) Assembler Skeleton'
         DB    ' Program',13,10
         DB    'Version 1.0 ',??date,' ',??time,13,10
         DB    'developed using Borland''s Turbo Assembler 3.1',13,10
         DB    'by Bill Magaletta, CIS [72411,2473]',13,10
         DB    13,10
Msg1l    =     $-Msg1

Msg2     DB    'The title lines were displayed using Dos32PutMessage,'
         DB    ' but this message',13,10
         DB    'is being displayed using Dos32Write.',13,10
         DB    13,10
         DB    'Now let''s see your command line arguments...',13,10
         DB    13,10
Msg2l    =     $-Msg2

Msg98    DB    '{'
Msg99    DB    '}',13,10
Msg99l   =     $-Msg99

; COMMAND LINE PARSE
ARSMAX   =     2                   ;max arg strings from OS/2
ARGMAX   =     16                  ;max arg strings after scan
argc     DD    0                   ;no. of args
argv     DQ    ARGMAX dup(?)       ;array of (offset,length)

count    dd    0
         ENDS

;----------------------------------------------------------------------
; MAIN PROGRAM
;----------------------------------------------------------------------

         CODESEG

SKELOS32:

; Display Program Titles
         CALL  Dos32PutMessage syscall,\
               1,\                  stdout handle
               Msg1l,\              msg length
               OFFSET Msg1         ;->msg
         CALL  Dos32Write syscall,\
               1,\                  stdout handle
               OFFSET Msg2,\        ->buffer
               Msg2l,\              buffer length
               OFFSET count        ;->returned length

; Parse Command Line Arguments
         CALL  CmdParse pascal,\
               [dword ss:esp+16],\  ->command line
               OFFSET argc,\        ->argument count
               OFFSET argv         ;->argument array

; Display Command Line Arguments
         mov    ecx,[argc]
         mov    esi,0
ListArgs:
         push   ecx
         CALL   Dos32PutMessage syscall,\
                1,\
                1,\
                OFFSET Msg98
         CALL   Dos32PutMessage syscall,\
                1,\
                [dword argv+esi+4],\
                [dword argv+esi]
         CALL   Dos32PutMessage syscall,\
                1,\
                Msg99l,\
                OFFSET Msg99
         add    esi,8
         pop    ecx
         loop   ListArgs

         RET


         LOCALS

;----------------------------------------------------------------------
; CmdParse : OS/2 Command Line Parse
;
; ARGUMENTS
;
;   @cmd :dword -> OS/2 Command Line
;
;     OS/2 command line consists of three (3) null-terminated strings:
;     program name, arguments, and null.
;
;
;   @argc:dword -> Argument Count (dword)                   (output)
;
;     Receives the number of arguments (including the program name).
;
;
;   @argv:dword -> Array of (dword->arg, dword arg length)  (output)
;
;     Receives offset and length for each argument.  Length does not
;     include the null terminator.
;
;
; LOGIC
;
; Two passes:
;
;   @@GetString - Scans the command line and produces output (argc,argv)
;     for two arguments: the program name, and the arguments string.
;
;   @@GetSubstr - Scans the arguments string (argv[1]) and breaks out
;     the individual arguments.  Initially, argv[1] describes the entire
;     arguments string.  Then, argv[1].length is set to the length of
;     1st individual argument, and argv[2] is set to describe the
;     remaining string.  This is repeated for argv[2], and so forth.
;
;----------------------------------------------------------------------
 
         PROC   pascal CmdParse near
         ARG    @cmd:dword, @argc:dword, @argv:dword

;----------------------------------------
; 1st Pass: Get Strings Provided by OS/2
;----------------------------------------

         mov    edi,[@cmd]         ;edi ->command line
         mov    ecx,ARSMAX         ;ecx = max arg strings from OS/2
         mov    esi,0              ;esi = offset to argv[current]

@@GetString:
         push   ecx                ;save loop count
         mov    edx,edi            ;edx ->argument string
         mov    eax,0              ;eax = null terminator (scasb arg)
         mov    ecx,256            ;ecx = max. scan length
         cld                       ;find null terminator
         repnz  scasb
         sub    ecx,256            ;ecx = string length
         neg    ecx
         dec    ecx
         mov    ebx,[@argv]        ;ebx ->argv
         mov    [ebx+esi+0],edx    ;argv[esi].offset = string offset
         mov    [ebx+esi+4],ecx    ;argv[esi].length = string length
         add    esi,8              ;next argv element
         pop    ecx                ;restore loop count
         cmp    [byte es:edi],0    ;check for last arg (double null)
         loopne @@GetString        ;loop 'til last arg or ARSMAX

         sub    ecx,ARSMAX         ;ecx  = number of args
         neg    ecx
         mov    ebx,[@argc]        ;argc = ecx
         mov    [ebx],ecx
         cmp    ecx,2              ;return if < 2 args
         jb     @@Return

;----------------------------------------
; 2nd Pass: Get Individual Arguments
;----------------------------------------

         mov    ebx,[@argv]        ;ebx ->argv
         mov    esi,8              ;esi = offset to argv[1]
         mov    ecx,ARGMAX         ;ecx = max. individual arguments
         mov    edi,[ebx+esi+0]    ;edi = argv[1].offset
         mov    eax,[ebx+esi+4]    ;eax = argv[1].length

@@GetSubstr:
         push   ecx                ;save loop count
         mov    ecx,eax            ;ecx = max. scan length
         mov    eax,' '            ;eax = space (scasb arg)
         cld                       ;skip leading spaces
         repz   scasb
         jz     @@GetSubExit       ;quit if all spaces
         dec    edi                ;edi ->argument
         inc    ecx                ;ecx = string length at argument
         mov    [ebx+esi+0],edi    ;argv[curr].offset = edi
         mov    [ebx+esi+4],ecx    ;argv[curr].length = ecx
         repnz  scasb              ;find end-of-argument
         mov    [ebx+esi+8],edi    ;argv[next].offset = edi
         mov    [ebx+esi+12],ecx   ;argv[next].length = ecx
         mov    eax,[ebx+esi+4]    ;eax = argv[curr].length - ecx
         sub    eax,ecx            ;(that's the argument length if we
         cmp    [byte edi-1],' '   ;didn't scan to end-of-string, but
         jne    @@GetSubLen        ;it's one greater if we did.)
         dec    eax
@@GetSubLen:
         mov    [ebx+esi+4],eax    ;argv(curr].length = eax
         mov    eax,ecx            ;eax = remaining string length
         add    esi,8              ;esi = offset to argv[next]
         pop    ecx                ;restore loop count
         cmp    [byte edi],0       ;repeat 'til end-of-string
         loopne @@GetSubstr
         push   ecx                ;compensating push
@@GetSubExit:
         pop    ecx                ;restore loop count
         sub    ecx,ARGMAX         ;argc = number of args
         neg    ecx
         dec    ecx
         mov    ebx,[@argc]
         add    [ebx],ecx
@@Return:
         ret

         ENDP   CmdParse

         ENDS

         END   SKELOS32
