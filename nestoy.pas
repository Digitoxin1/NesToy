program NesToy;
{$X+}
{$M 40960,0,655360}

uses
  dos,dos70,crc32new,crt,strings,runtime;
const
  maxdbasesize=3200;
  maxdirsize=3500;
  maxpathnames=100;
type
  neshdr=record
           hdr:string[4];      {4 byte header string (NES^Z)}
           prg:byte;           {16k Program Data Blocks}
           chr:byte;           {8k Chr Data Blocks}
           mirror:byte;        {Mirroring}
           sram:byte;          {Battery Backup}
           trainer:byte;       {Trainer}
           fourscr:byte;       {Four Screen}
           mapper:byte;        {Mapper #}
           vs:byte;            {VS.}
           pc10:byte;          {Playchoice-10}
           other:string[8];    {Misc. Header Bytes {Should be $00's)}
           country:integer;    {Country Code (Not in header)}
           company:string[25]; {Company (Not in header)}
         end;
  updown   = (ascending,descending);
  charstr  = array[0..255] of char;     { the Type of data to be sorted }
  dataptr  = ^charstr;
  ptrArray = Array[1..maxdirsize] of dataptr;
  Arrayptr = ^ptrArray;

const
  null8=#0+#0+#0+#0+#0+#0+#0+#0;
  hdrstring='NES'+#26;
  dbasefile='NESDBASE.DAT';
  cfgfile='NESTOY.CFG';
  outputfile='OUTPUT.TXT';
  logfile='NESTOY.LOG';
  version='3.1';
  SortType:updown = ascending;
  missingfile:string='MISSING.TXT';
  extparamst:string='';
  dir_base:string='';
  dir_backup:string='Backup\';
  dir_bad:string='Bad\';
  dir_canada:string='Canada\';
  dir_china:string='China\';
  dir_dupes:string='Dupes\';
  dir_europe:string='Europe\';
  dir_gamehacks:string='Game Hacks\';
  dir_hacked:string='Hacked\';
  dir_japan:string='Japan\';
  dir_maphacks:string='Mapper Hacks\';
  dir_pc10:string='Playchoice 10\';
  dir_pirate:string='Pirate\';
  dir_repair:string='Repair\';
  dir_sweden:string='Sweden\';
  dir_trans:string='Translated\';
  dir_unknown:string='Unknown\';
  dir_unlicensed:string='Unlicensed\';
  dir_usa:string='USA\';
  dir_vs:string='VS Unisystem\';
  dir_savestates:string='';
  move_bad:boolean=true;
  move_hacked:boolean=true;
  move_pirate:boolean=true;
  missing_bad:boolean=false;
  missing_gamehacks:boolean=false;
  missing_hacked:boolean=true;
  missing_pirate:boolean=true;
  missing_trans:boolean=false;
  shortname:boolean=false;
  win2000:boolean=false;
  badchr:string=' (Bad CHR';

var
  hdcsum:boolean;
  csumdbase:array[1..maxdbasesize] of record
                                        str:pchar;
                                        flag:boolean;
                                        resize:integer;
                                      end;
  prgdbase:array[1..maxdbasesize] of pchar;
  dirarray:array[1..maxdirsize] of pchar;
  FCPrg,FCChr:array[1..200] of byte;
  path:array[1..maxpathnames] of pchar;
  clf:array[1..maxpathnames] of pchar;
  dbasecount,FCCount,numpaths:integer;
  cpath,progpath:string;
  cfgparam:string;
  flagrom:boolean;
  overwritemissing:boolean;
  logging,wrotelog,quiet,outquiet:boolean;
  lfile:text;

function upcasestr(s:string):string;
var
  i:integer;
begin
  for i:=1 to length(s) do
    s[i]:=upcase(s[i]);
  upcasestr:=s;
end;

function lowcasestr(s:string):string;
var
  i:integer;
begin
  for i:=1 to length(s) do
    if (ord(s[i])>64) and (ord(s[i])<91) then s[i]:=chr(ord(s[i])+32);
  lowcasestr:=s;
end;

procedure setlfntime(fname:string);
var
  h,m,s,ms:word;
  y,mo,d,dow:word;
  stime:newdatetime;
begin
  gettime(h,m,s,ms);
  getdate(y,mo,d,dow);
  stime.hour:=h;
  stime.minute:=m;
  stime.second:=s;
  stime.millisecond:=ms;
  stime.year:=y;
  stime.month:=mo;
  stime.day:=d;
  lfnsetmodiftime(fname,stime);
end;

function compare(str1,str2:pchar):integer;
var
  s1,s2:string;
  l,c,ctemp:integer;
begin
  s1:=strpas(str1);
  s2:=strpas(str2);
  c:=0;
  ctemp:=0;
  if copy(s1,length(s1)-3,1)='.' then delete(s1,length(s1)-3,4);
  if copy(s2,length(s2)-3,1)='.' then delete(s2,length(s2)-3,4);
  if length(s1)<length(s2) then l:=length(s1) else l:=length(s2);
  repeat
    c:=c+1;
    if upcase(s1[c])<upcase(s2[c]) then ctemp:=-1;
    if upcase(s1[c])>upcase(s2[c]) then ctemp:=1;
  until (ctemp<>0) or (c=l);
  compare:=ctemp;
end;

Procedure swap(Var a,b : dataptr);  { Swap the Pointers }
Var  t:dataptr;
begin
  t:=a;
  a:=b;
  b:=t;
end;

Procedure QuickSort(Var da; left,right:Word);
Var
  d     :ptrArray Absolute da;
  pivot :charstr;
  lower,
  upper,
  middle: Word;
  t,counter:integer;
  P:longint;
begin
  lower:=left;
  upper:=right;
  middle:=(left + right) div 2;
  pivot:=d[middle]^;
  Repeat
    Case SortType of
    ascending :begin
                 While compare(d[lower]^,pivot)<0 do inc(lower);
                 While compare(pivot,d[upper]^)<0 do dec(upper);
               end;
    descending:begin
                 While compare(d[lower]^,pivot)>0 do inc(lower);
                 While compare(pivot,d[upper]^)>0 do dec(upper);
               end;
    end; { Case}
    if lower <= upper then begin
      { swap the Pointers not the data }
      swap(d[lower],d[upper]);
      inc(lower);
      dec(upper);
    end;
  Until lower > upper;
  if left < upper then QuickSort(d,left,upper);
  if lower < right then QuickSort(d,lower,right);
end;  { QuickSort }

procedure pause;
var
  dummy:char;
begin
  write('Press any key to continue');
  repeat until keypressed=true;
  dummy:=readkey;
  gotoxy(1,wherey);
  clreol;
end;

function removecomment(instr:string):string;
var
  p1,p2:integer;
begin
  repeat
    p1:=pos('{',instr);
    p2:=pos('}',instr);
    if (p1>0) and (p2>0) and (p1<p2) then
      delete(instr,p1,p2-p1+1);
  until (p1=0) or (p2=0) or (p1>p2);
  removecomment:=instr;
end;

function removespaces(instr:string;rp:boolean):string;
begin
  while (instr[1]=' ') and (length(instr)>0) do delete(instr,1,1);
  while (instr[length(instr)]=' ') and (length(instr)>0) do delete(instr,length(instr),1);
  if (rp=true) and (length(instr)>1) then
    if instr[1]='"' then
      begin
        delete(instr,1,1);
        if instr[length(instr)]='"' then delete(instr,length(instr),1);
      end;
  removespaces:=instr;
end;

function I2S(i: longint;pad:integer): string;
var
  s:string[15];
begin
  str(i,s);
  if pad>0 then
    while length(s)<pad do s:='0'+s;
  I2S:=s;
end;

function S2I(s:string):integer;
var
  i,code:integer;
begin
  val(s,i,code);
  s2i:=i;
end;

procedure str2chr(strtemp:string;var result:charstr);
var
  len,counter:integer;
begin
  len:=length(strtemp);
  for counter:=1 to len do
    result[counter-1]:=strtemp[counter];
  result[len]:=#0;
end;

function sstr(str:string;i:integer):string;
begin
  if i=1 then sstr:=str else sstr:=str+'s';
end;

function find(substr:string;str:string):boolean;
var
  op,cp:integer;
  ptemp:boolean;
begin
  ptemp:=false;
  op:=pos('(',str);
  cp:=pos(')',str);
  if (op>0) and (cp>op) then
    begin
      str:=copy(str,op,cp-op+1);
      if pos(substr,str)>0 then ptemp:=true;
    end;
  find:=ptemp;
end;

function justify(s:string;i:integer;jtype:char;trflag:boolean):string;
var
  counter:integer;
begin
  if length(s)<i then
    case jtype of
      'L': while length(s)<i do s:=s+' '; {Left}
      'R': while length(s)<i do s:=' '+s; {Right}
      'C': for counter:=1 to (i-length(s)) div 2 do s:=' '+s; {Center}
    end;
  if (length(s)>i) and (trflag=true) then s:=copy(s,1,i);
  justify:=s;
end;

function movethe(instr:string):string;
var
  p:integer;
begin
  p:=pos(', The',instr);
  if p>0 then
    begin
      delete(instr,p,5);
      instr:='The '+instr;
    end;
  movethe:=instr;
end;


function paramstrparse:string;
var
  s1,s2:string;
  cp:string;
  counter,p:integer;
  flag:boolean;
begin
  flag:=false;
  s1:='';
  for counter:=1 to paramcount do
    begin
      s2:=paramstr(counter);
      if copy(s2,1,1)='"' then
        begin
          flag:=true;
          delete(s2,1,1);
        end;
      if copy(s2,length(s2),1)='"' then
        begin
          flag:=false;
          delete(s2,length(s2),1);
        end;
      if flag=true then s1:=s1+s2+' '
                   else s1:=s1+s2+',';
    end;
  if copy(s1,length(s1),1)<>',' then
    begin
      while copy(s1,length(s1),1)=' ' do
        delete(s1,length(s1),1);
      s1:=s1+',';
    end;
  if s1=',' then s1:='';
  flag:=false;
  cp:=cfgparam;
  if cp>'' then
    repeat
      p:=pos(' ',cp);
      if p=0 then
        begin
          if copy(cp,length(cp),1)='"' then delete(cp,length(cp),1);
          s1:=s1+cp+','
        end else
        begin
          s2:=copy(cp,1,p-1);
          delete(cp,1,p);
          if copy(s2,1,1)='"' then
            begin
              flag:=true;
              delete(s2,1,1);
            end;
          if copy(s2,length(s2),1)='"' then
            begin
              flag:=false;
              delete(s2,length(s2),1);
            end;
          if flag=true then s1:=s1+s2+' ' else
            begin
              s1:=s1+s2+',';
              while cp[1]=' ' do delete(cp,1,1);
            end;
        end;
    until p=0;
  paramstrparse:=s1;
end;

function extparamcount:integer;
var
  s:string;
  i:integer;
begin
  i:=0;
  s:=extparamst;
  while pos(',',s)>0 do
    begin
      delete(s,1,pos(',',s));
      i:=i+1;
    end;
  extparamcount:=i;
end;

function extparamstr(pnum:integer):string;
var
  s1,s2:string;
  count,p:integer;
begin
  s1:=extparamst;
  count:=extparamcount;
  if pnum>count then
    begin
      extparamstr:='';
      exit;
    end;
  count:=0;
  repeat
    count:=count+1;
    p:=pos(',',s1);
    s2:=copy(s1,1,p-1);
    delete(s1,1,p);
  until count>=pnum;
  extparamstr:=s2;
end;

function countrys2i(s:string):integer;
var
  temp:integer;
begin
  temp:=0;
  if pos('J',s)>0 then temp:=temp+1;     {Japan}
  if pos('U',s)>0 then temp:=temp+2;     {USA}
  if pos('E',s)>0 then temp:=temp+4;     {Europe}
  if pos('S',s)>0 then temp:=temp+8;     {Sweden}
  if pos('F',s)>0 then temp:=temp+16;    {French-Canadian}
  if pos('C',s)>0 then temp:=temp+32;    {China}
  if pos('X',s)>0 then temp:=temp+64;    {Unlicensed}
  if pos('V',s)>0 then temp:=temp+128;   {VS Unisystem}
  if pos('P',s)>0 then temp:=temp+256;   {Playchoice-10}
  if pos('T',s)>0 then temp:=temp+512;   {Translated}
  if pos('Z',s)>0 then temp:=temp+1024;  {Pirate}
  if pos('M',s)>0 then temp:=temp+2048;  {Mapper Hack}
  if pos('G',s)>0 then temp:=temp+4096;  {Game Hack}
  if pos('H',s)>0 then temp:=temp+8192;  {Hacked}
  if pos('B',s)>0 then temp:=temp+16384; {Bad Dump}
  countrys2i:=temp;
end;

function countryi2s(i:integer):string;
var
  temp:string[7];
begin
  temp:='';
  i:=i mod 512;
  case i of
    1: temp:=' (J)';
    2: temp:=' (U)';
    3: temp:=' (JU)';
    4: temp:=' (E)';
    5: temp:=' (JE)';
    6: temp:=' (UE)';
    7: temp:=' (JUE)';
    8: temp:=' (S)';
    16: temp:=' (F)';
    32: temp:=' (C)';
    64: temp:=' (UNL)';
    128: temp:=' (VS)';
    256: temp:=' (PC10)';
  end;
  countryi2s:=temp;
end;

function exist(fname:string):boolean;
var
  f:word;
  dirinfo:tfinddata;
begin
  exist:=false;
  f:=lfnfindfirst(fname,FA_NORMAL,FA_NORMAL,dirinfo);
  if dos7error=0 then exist:=true;
  lfnfindclose(f);
end;

function transdir(str:string):string;
var
  tempstr:string;
begin
  tempstr:='';
  str:=upcasestr(str);
  if pos('(BRAZIL',str)>0 then tempstr:='Portuguese';
  if pos('(ENGLISH',str)>0 then tempstr:='English';
  if pos('(GERMAN',str)>0 then tempstr:='German';
  if pos('(PORTUGUESE',str)>0 then tempstr:='Portuguese';
  if pos('(SPANISH',str)>0 then tempstr:='Spanish';
  if pos('(SWEDISH',str)>0 then tempstr:='Swedish';
  if tempstr='' then tempstr:='Unknown';
  transdir:=tempstr;
end;

procedure searchps(s:string;var p:integer;var value:string);
var
  found,count:integer;
  s2,s3,valtemp:string;
  flag:boolean;
begin
  value:='';
  flag:=false;
  found:=-1;
  count:=0;
  if (s[length(s)]='#') or (s[length(s)]='*') then flag:=true;
  while (count<=extparamcount) and (found<>count) do
    begin
      count:=count+1;
      s2:=upcasestr(extparamstr(count));
      s3:=upcasestr(s);
      if flag=true then
        begin
          delete(s3,length(s3),1);
          valtemp:=copy(s2,length(s3)+1,length(s2)-length(s3));
          s2:=copy(s2,1,length(s3));
        end;
      if s2=s3 then
        begin
          found:=count;
          value:=valtemp;
        end;
    end;
  p:=found;
end;

procedure splitpath(pathname:string;var fname:string;var path:string);
var
  slashflag:boolean;
  p:integer;
begin
  fname:='';
  path:='';
  if pathname[2]=':' then
    begin
       path:=path+copy(pathname,1,2);
       if pathname[3]<>'\' then path:=path+'.\';
       delete(pathname,1,2);
    end;
  while pos('\',pathname)>0 do
    begin
      p:=pos('\',pathname);
      path:=path+copy(pathname,1,p);
      delete(pathname,1,p);
    end;
  fname:=pathname;
  if path='' then path:='.\';
end;

function getsortdir(code:integer):string;
var
  tempdir:string;
begin
  tempdir:='';
  if code>0 then code:=code mod 1024;
  case code of
   -5:tempdir:=dir_pirate;
   -4:tempdir:=dir_maphacks;
   -3:tempdir:=dir_gamehacks;
   -2:tempdir:=dir_hacked;
   -1:tempdir:=dir_bad;
    0:tempdir:=dir_unknown;
    1,5:tempdir:=dir_japan;
    2,3,6,7:tempdir:=dir_usa;
    4:tempdir:=dir_europe;
    8:tempdir:=dir_sweden;
    16:tempdir:=dir_canada;
    32:tempdir:=dir_china;
    64:tempdir:=dir_unlicensed;
    128:tempdir:=dir_vs;
    256:tempdir:=dir_pc10;
    512:tempdir:=dir_trans;
  end;
  getsortdir:=tempdir;
end;

function romsize(fname:string):integer;
var
  fsfile:file;
  fs:integer;
begin
  assign(fsfile,getshortpathname(fname,false));
  reset(fsfile,8192);
  fs:=filesize(fsfile);
  close(fsfile);
  romsize:=fs;
end;

procedure getcrc(fname:string;var retcrc,retprgcrc:string;var garbage:boolean;prg:byte);
var
  crc,prgcrc:longint;
  f,result:word;
  buf:CRCBuf;
  ctr,g,prgctr:integer;
begin
  garbage:=false;
  g:=0;
  prgctr:=prg*2;
  crc:=crcseed;
  f:=LFNOpenFile(fname,FA_NORMAL,OPEN_RDONLY,1);
  result:=lfnblockread(f,buf,16);
  if hdcsum=true then
    crc:=crc32(buf,crc,16);
  repeat
    if prgctr<>-1 then prgctr:=prgctr-1;
    result:=lfnblockread(f,buf,sizeof(buf));
    g:=result mod 8192;
    if g>=512 then g:=g-512;
    if g>0 then garbage:=true;
    crc:=crc32(buf,crc,result-g);
    if prgctr=0 then prgcrc:=crcend(crc);
  until result=0;
  LFNCloseFile(f);
  crc:=crcend(crc);
  retcrc:=crchex(crc);
  retprgcrc:=crchex(prgcrc);
end;

procedure logoutput(str:string);
var
  p:integer;
  flag:boolean;
  Year,Month,Day,DOW:word;
  Hour,Min,Sec,Sec100:word;
begin
  if wrotelog=false then
    begin
      getdate(year,month,day,dow);
      gettime(hour,min,sec,sec100);
      writeln(lfile,'------------------------------------------------------------------------------');
      if month<10 then write(lfile,'0',month,'/') else write(lfile,month,'/');
      if day<10 then write(lfile,'0',day,'/') else write(lfile,day,'/');
      write(lfile,year,' - ');
      if hour<10 then write(lfile,'0',hour,':') else write(lfile,hour,':');
      if min<10 then write(lfile,'0',min,':') else write(lfile,min,':');
      if sec<10 then writeln(lfile,'0',sec) else writeln(lfile,sec);
      writeln(lfile,'------------------------------------------------------------------------------');
      wrotelog:=true;
    end;
  flag:=false;
  repeat
    if length(str)<79 then
      begin
        writeln(lfile,str);
        flag:=true;
      end else
      begin
        p:=78;
        while (str[p]<>' ') and (p>1) do p:=p-1;
        writeln(lfile,copy(str,1,p-1));
        delete(str,1,p);
      end;
  until flag=true;
  writeln(lfile);
end;

function LFNMD(newdir:string):word;
var
  dir2:string;
  d:char;
  f,err:word;
  dirinfo:tfinddata;
begin
  dir2:=newdir;
  f:=LFNFindFirst(newdir,FA_DIR,FA_DIR,dirinfo);
  err:=dos7error;
  LFNFindClose(f);
  if (err=2) or (err=3) then
    begin
      LFNMkDir(newdir);
      err:=dos7error;
      if err>0 then
        begin
          if pos('\',dir2)>0 then
            begin
              repeat
                d:=dir2[length(dir2)];
                delete(dir2,length(dir2),1);
              until d='\';
              f:=LFNFindFirst(dir2,FA_DIR,FA_DIR,dirinfo);
              err:=dos7error;
              LFNFindClose(f);
              if (err=2) or (err=3) then LFNMkDir(dir2);
            end;
          LFNMkDir(newdir);
          err:=dos7error;
        end;
    end;
  LFNMD:=err;
end;

procedure LFNMove(sourcepath,destpath,crc,ccode:string;var errcode:word);
var
  sf,df,sresult,dresult:word;
  buf:array[1..16384] of byte;
  sp,sn,dp,dn,sptemp,dptemp:string;
  existb,garbage:boolean;
  ctr,p:integer;
  newcrc,dnc,dummy:string;

begin
  errcode:=0;
  ctr:=0;
  splitpath(sourcepath,sn,sp);
  sp:=getshortpathname(sp,false);
  splitpath(destpath,dn,dp);
  errcode:=LFNMD(copy(dp,1,length(dp)-1));
  if errcode=0 then
    begin
      dp:=getshortpathname(dp,false);
      if dn='' then dn:=sn;
      sourcepath:=sp+sn;
      destpath:=dp+dn;
      dnc:=dn;
      if upcasestr(sourcepath)<>upcasestr(destpath) then
        begin
          if crc<>'' then
            begin
              if ccode<>'' then
                begin
                  p:=pos(ccode,upcasestr(dnc));
                  if p>0 then delete(dnc,p,length(ccode)) else
                  if copy(dnc,length(dnc)-3,1)='.'
                    then insert(ccode,dnc,length(dnc)-3)
                      else dnc:=dnc+ccode;
                end;
              if exist(destpath) then
                begin
                  getcrc(destpath,newcrc,dummy,garbage,0);
                  if newcrc=crc then
                    begin
                      flagrom:=false;
                      dp:=dir_dupes;
                      destpath:=dp+dn;
                      errcode:=LFNMD(copy(dp,1,length(dp)-1));
                    end else
                    if ccode<>'' then
                      begin
                        destpath:=dp+dnc;
                        if upcasestr(sourcepath)<>upcasestr(destpath) then
                          begin
                            if exist(destpath) then
                              begin
                                getcrc(destpath,newcrc,dummy,garbage,0);
                                if newcrc=crc then
                                  begin
                                    flagrom:=false;
                                    dp:=dir_dupes;
                                    destpath:=dp+dn;
                                    errcode:=LFNMD(copy(dp,1,length(dp)-1));
                                 end else errcode:=5;
                              end;
                          end else errcode:=5;
                      end else errcode:=5;
                end;
            end;
          if errcode=0 then
            begin
              repeat
                ctr:=ctr+1;
                existb:=exist(destpath);
                if existb=true then
                  begin
                    if ctr<10 then delete(destpath,length(destpath),1);
                    if ctr>=10 then delete(destpath,length(destpath)-1,2);
                   destpath:=destpath+i2s(ctr,0);
                 end;
              until existb=false;
              if upcasestr(copy(sp,1,2))=upcasestr(copy(dp,1,2)) then
                begin
                  LFNRename(sourcepath,destpath);
                  errcode:=dos7error;
                end else
                begin
                  sf:=LFNOpenFile(sourcepath,FA_RDONLY,OPEN_RDONLY,1);
                  df:=LFNCreateFile(destpath,FA_NORMAL,OPEN_WRONLY,1);
                  errcode:=dos7error;
                  if errcode=0 then
                    begin
                      repeat
                        sresult:=lfnblockread(sf,buf,sizeof(buf));
                        dresult:=lfnblockwrite(df,buf,sresult);
                      until (sresult=0) or (sresult<>dresult);
                      errcode:=dos7error;
                      if errcode=0 then LFNErase(sourcepath,FA_NORMAL,FA_NORMAL,False);
                      LFNCloseFile(df);
                    end;
                  LFNCloseFile(sf);
                end;
            end;
        end else
        begin
          errcode:=100;
          if sn<>dn then
            begin
              LFNRename(sourcepath,destpath);
              errcode:=dos7error;
            end;
        end;
    end;
  if (errcode>0) and (errcode<>100) and (logging=true) then
    begin
      sp:=getlongpathname(sp,false);
      if exist(dp) then dp:=getlongpathname(dp,false) else dp:=getfullpathname(dp,false);
      sptemp:=upcasestr(sp);
      dptemp:=upcasestr(dp);
      if (sptemp=dptemp) and (sn<>dn) then logoutput('Unable to rename '+sn+' to '+dn+' in '+sp+'.');
      if (sptemp<>dptemp) and (sn=dn) then logoutput('Unable to move '+sn+' from '+sp+' to '+dp+'.');
      if (sptemp<>dptemp) and (sn<>dn) then logoutput('Unable to move '+sp+sn+' to '+dp+dn+'.');
    end else setlfntime(destpath);
end;

procedure renamesaves(result,name:string);
var
  f:word;
  dirinfo:tfinddata;
  tempstr,tempres:string;
begin
  if copy(name,length(name)-3,1)='.' then
    name:=copy(name,1,length(name)-4);
  f:=LFNFindFirst(dir_savestates+name+'.*',FA_NORMAL,FA_NORMAL,dirinfo);
  while dos7error=0 do
    begin
      tempstr:=dirinfo.name;
      tempstr:=copy(tempstr,length(tempstr)-3,4);
      if (upcasestr(tempstr)='.SAV') or (upcasestr(copy(tempstr,1,3))='.ST') then
        begin
          tempres:=result+tempstr;
          lfnrename(dir_savestates+dirinfo.name,dir_savestates+tempres);
        end;
      LFNFindNext(f,dirinfo);
    end;
  LFNFindClose(f);
end;

procedure GetNesHdr(var nh:neshdr;hdr:string);
begin
  nh.hdr:=copy(hdr,1,4);
  nh.prg:=ord(hdr[5]);
  nh.chr:=ord(hdr[6]);
  nh.mirror:=ord(hdr[7]) mod 2;
  nh.sram:=ord(hdr[7]) div 2 mod 2;
  nh.trainer:=ord(hdr[7]) div 4 mod 2;
  nh.fourscr:=ord(hdr[7]) div 8 mod 2;
  nh.mapper:=ord(hdr[7]) div 16+ord(hdr[8]) div 16*16;
  nh.other:=copy(hdr,9,8);
  nh.vs:=ord(hdr[8]) mod 2;
  nh.pc10:=ord(hdr[8]) div 2 mod 2;
  nh.country:=0;
  nh.company:='';
end;

function SetNesHdr(nh:neshdr):string;
var
  tmpstr:string[16];
  byte7,byte8:byte;
begin
  tmpstr:='';
  byte7:=0;
  byte8:=0;
  tmpstr:=nh.hdr+chr(nh.prg)+chr(nh.chr);
  byte7:=nh.mirror+nh.sram*2+nh.trainer*4+nh.fourscr*8+nh.mapper mod 16*16;
  byte8:=nh.vs+nh.pc10*2+nh.mapper div 16*16;
  tmpstr:=tmpstr+chr(byte7)+chr(byte8)+nh.other;
  SetNesHdr:=tmpstr;
end;

procedure GetDBaseInfo(count:integer;var fname:string;var DbaseInfo:neshdr);
var
  f:text;
  counter,p,x,code:integer;
  ts,ts2:string;
  byte7,byte8:byte;
begin
  assign(f,progpath+dbasefile);
  reset(f);
  for counter:=1 to count do
    readln(f,ts);
  p:=pos(';',ts); delete(ts,1,p);
  p:=pos(';',ts); delete(ts,1,p);
  if csumdbase[count].resize>0 then
    begin
      p:=pos(';',ts); delete(ts,1,p);
      p:=pos(';',ts); delete(ts,1,p);
    end;
  p:=pos(';',ts);
  if p=0 then fname:=ts else
    begin
      fname:=copy(ts,1,p-1);
      delete(ts,1,p);
    end;
  p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); byte7:=x;
  p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); byte8:=x;
  p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); dbaseinfo.prg:=x;
  p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
  val(ts2,x,code); dbaseinfo.chr:=x;
  p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
  dbaseinfo.country:=countrys2i(ts2);
  p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
  dbaseinfo.company:=ts2;
  dbaseinfo.mirror:=byte7 mod 2;
  dbaseinfo.sram:=byte7 div 2 mod 2;
  dbaseinfo.trainer:=byte7 div 4 mod 2;
  dbaseinfo.fourscr:=byte7 div 8 mod 2;
  dbaseinfo.mapper:=byte7 div 16+byte8 div 16*16;
  dbaseinfo.vs:=byte8 mod 2;
  dbaseinfo.pc10:=byte8 div 2 mod 2;
  dbaseinfo.hdr:=hdrstring;
  dbaseinfo.other:=null8;
  close(f);
end;

procedure SearchDBase(cs:string;var fnd:integer);
var
  low,low2,high,mid:integer;
  found:boolean;
begin
  fnd:=0;
  low:=0;
  low2:=0;
  high:=dbasecount+1;
  mid:=high;
  found:=false;
  while (found<>true) and (low2<mid) do
    begin
      low2:=low;
      mid:=(high-low) div 2+low;
      if strpas(csumdbase[mid].str)=cs then found:=true
        else if strpas(csumdbase[mid].str)>cs then high:=mid
          else low:=mid;
    end;
  if found=true then fnd:=mid;
end;

procedure SearchPRGDbase(cs:string;var fnd:integer);
var
  low,low2,high,mid:integer;
  found:boolean;
  dbstr:string[13];
  dbpos:integer;
begin
  fnd:=0;
  low:=0;
  low2:=0;
  high:=dbasecount+1;
  mid:=high;
  found:=false;
  while (found<>true) and (low2<mid) do
    begin
      low2:=low;
      mid:=(high-low) div 2+low;
      dbstr:=strpas(prgdbase[mid]);
      dbpos:=s2i(copy(dbstr,9,length(dbstr)-8));
      dbstr:=copy(dbstr,1,8);
      if dbstr=cs then found:=true
        else if dbstr>cs then high:=mid
          else low:=mid;
    end;
  if found=true then fnd:=dbpos;
end;


procedure checkbanks(fname:string;prg:integer;chr:integer;var newprg:byte;var newchr:byte);
var
  prgcrc:array[1..128] of string[8];
  chrcrc:array[1..128] of string[8];
  crc:longint;
  f,result:word;
  fn:file;
  buf:CRCBuf;
  ctr,ctr2:integer;
  prgmatch,chrmatch:boolean;
begin
  if prg>128 then prg:=128;
  if chr>128 then chr:=128;
  prgmatch:=true;
  chrmatch:=true;
  f:=LFNOpenFile(fname,FA_NORMAL,OPEN_RDONLY,1);
  result:=lfnblockread(f,buf,16);
  if prg>1 then
    for ctr:=1 to prg do
      begin
        crc:=crcseed;
        for ctr2:=1 to 2 do
          begin
            result:=lfnblockread(f,buf,sizeof(buf));
            crc:=crc32(buf,crc,result);
          end;
        crc:=crcend(crc);
        prgcrc[ctr]:=crchex(crc);
      end;
  if chr>1 then
    for ctr:=1 to chr do
      begin
        crc:=crcseed;
        result:=lfnblockread(f,buf,sizeof(buf));
        crc:=crc32(buf,crc,result);
        crc:=crcend(crc);
        chrcrc[ctr]:=crchex(crc);
      end;
  LFNCloseFile(f);
  if (prg>1) and (prg mod 2=0) then
    begin
      prg:=prg div 2;
      ctr:=0;
      repeat
        if (ctr=prg) and (prgmatch=true) then
          begin
            ctr:=0;
            prg:=prg div 2;
          end;
        ctr:=ctr+1;
        if prgcrc[ctr]<>prgcrc[ctr+prg] then prgmatch:=false;
      until (prgmatch=false) or (prg=1);
      if (prg=1) and (prgmatch=true) then prg:=1 else prg:=prg*2;
    end;
  if (chr>1) and (chr mod 2=0) then
    begin
      chr:=chr div 2;
      ctr:=0;
      repeat
        if (ctr=chr) and (chrmatch=true) then
          begin
            ctr:=0;
            chr:=chr div 2;
          end;
        ctr:=ctr+1;
        if chrcrc[ctr]<>chrcrc[ctr+chr] then chrmatch:=false;
      until (chrmatch=false) or (chr=1);
      if (chr=1) and (chrmatch=true) then chr:=1 else chr:=chr*2;
    end;
  newprg:=prg;
  newchr:=chr;
end;

function ReadNesHdr(fname:string):string;
var
  f,result:word;
  hdr:array[1..16] of char;
begin
  f:=LFNOpenFile(fname,FA_NORMAL,OPEN_RDONLY,1);
  result:=lfnblockread(f,hdr,16);
  LFNCloseFile(f);
  readneshdr:=hdr;
end;

procedure WriteNesHdr(fname:string;nhdr:neshdr;var errcode:word);
var
  f,f2,result,result2:word;
  hdr:array[1..16] of char;
  buf:array[1..16384] of char;
  tstr:string[16];
  c,g:integer;
  rfname:string;
begin
  rfname:=fname;
  if copy(rfname,length(rfname)-3,1)='.' then rfname:=copy(rfname,1,length(rfname)-4);
  rfname:=rfname+'.ba~';
  LFNRename(fname,rfname);
  errcode:=dos7error;
  if errcode=0 then
    begin
      f:=LFNOpenFile(fname,FA_NORMAL,OPEN_WRONLY+OPEN_AUTOCREATE,1);
      f2:=LFNOpenFile(rfname,FA_NORMAL,OPEN_RDONLY,1);
      tstr:=setneshdr(nhdr);
      for c:=1 to 16 do hdr[c]:=tstr[c];
      result:=lfnblockwrite(f,hdr,16);
      result2:=lfnblockread(f2,hdr,16);
      repeat
        result2:=lfnblockread(f2,buf,sizeof(buf));
        g:=result2 mod 8192;
        if (g>=512) and (nhdr.trainer=1) then g:=g-512;
        if g>0 then result2:=result2-g;
        result:=lfnblockwrite(f,buf,result2);
      until (result2=0) or (result<>result2);
      LFNCloseFile(f);
      LFNCloseFile(f2);
    end else
      if logging=true then logoutput('Unable to repair '+getlongpathname('.\',false)+fname+'.');
end;

procedure CropRom(fname:string;nhdr:neshdr;var prg:byte;var chr:byte;newprg:byte;newchr:byte;var errcode:word);
var
  f,f2,result,result2:word;
  hdr:array[1..16] of char;
  buf:array[1..16384] of char;
  buf2:array[1..8192] of char;
  tstr:string[16];
  c,c2:integer;
  rfname:string;
  revprg,revchr:boolean;
  ctype:char;
begin
  ctype:=#255;
  revprg:=false;
  revchr:=false;
  if newprg>127 then begin newprg:=256-newprg; revprg:=true; end;
  if newchr>127 then begin newchr:=256-newchr; revchr:=true; end;
  rfname:=fname;
  if copy(rfname,length(rfname)-3,1)='.' then rfname:=copy(rfname,1,length(rfname)-4);
  rfname:=rfname+'.ba~';
  LFNRename(fname,rfname);
  errcode:=dos7error;
  if errcode=0 then
    begin
      f:=LFNOpenFile(fname,FA_NORMAL,OPEN_WRONLY+OPEN_AUTOCREATE,1);
      f2:=LFNOpenFile(rfname,FA_NORMAL,OPEN_RDONLY,1);
      nhdr.prg:=newprg;
      nhdr.chr:=newchr;
      tstr:=setneshdr(nhdr);
      for c:=1 to 16 do hdr[c]:=tstr[c];
      result:=lfnblockwrite(f,hdr,16);
      result2:=lfnblockread(f2,hdr,16);
      for c:=1 to prg do
        begin
          result2:=lfnblockread(f2,buf,sizeof(buf));
          if (c<=newprg) and (revprg=false) then result:=lfnblockwrite(f,buf,result2);
          if (c>newprg) and (revprg=true) then result:=lfnblockwrite(f,buf,result2);
        end;
      if newchr>chr then
        begin
          chr:=newchr;
          if revchr=true then begin revchr:=false; ctype:=#0; end;
        end;
      for c:=1 to chr do
        begin
          result2:=lfnblockread(f2,buf2,sizeof(buf2));
          if result2<sizeof(buf2) then
            begin
              for c2:=result2+1 to sizeof(buf2) do
                buf2[c2]:=ctype;
              result2:=sizeof(buf2);
            end;
          if (c<=newchr) and (revchr=false) then result:=lfnblockwrite(f,buf2,result2);
          if (c>newchr) and (revchr=true) then result:=lfnblockwrite(f,buf2,result2);
        end;
      LFNCloseFile(f);
      LFNCloseFile(f2);
      prg:=newprg;
      chr:=newchr;
    end else
      if logging=true then logoutput('Unable to resize '+getlongpathname('.\',false)+fname+'.');
end;

function readdir(pathname:string):word;
var
  count,counter:integer;
  dirinfo:tfinddata;
  f:word;
  arraytemp:charstr;
begin
  count:=0;
  f:=lfnfindfirst(pathname,FA_NORMAL,FA_NORMAL,dirinfo);
  while (dos7error=0) and (count<maxdirsize) do
    begin
      count:=count+1;
      str2chr(dirinfo.name,arraytemp);
      dirarray[count]:=strnew(arraytemp);
      lfnfindnext(f,dirinfo);
    end;
  lfnfindclose(f);
  readdir:=count;
  quicksort(dirarray,1,count);
end;

procedure readdirclose(count:word);
var
  counter:integer;
begin
  for counter:=count downto 1 do
    strdispose(dirarray[counter]);
end;

procedure patharrayclear(count:word);
var
  counter:integer;
begin
  for counter:=count downto 1 do
    strdispose(path[counter]);
    strdispose(clf[counter]);
end;

function expandwork(pn:string;addbase:boolean):string;
var
  tp,tf:string;
begin
  if addbase=true then
    if (copy(pn,1,1)<>'\') and (copy(pn,1,2)<>'.\') and (copy(pn,2,2)<>':\') then pn:=dir_base+pn;
  if pn='' then pn:='.\';
  if (copy(pn,length(pn),1)='\') and (copy(pn,length(pn)-1,2)<>'.\') and (copy(pn,length(pn)-1,2)<>':\')
    then delete(pn,length(pn),1);
  splitpath(pn,tf,tp);
  tp:=getfullpathname(tp,false);
  pn:=tp+tf;
  if (copy(pn,length(pn),1))<>'\'then pn:=pn+'\';
  expandwork:=pn;
end;

procedure expandpaths;
begin
  dir_base:=expandwork(dir_base,false);
  dir_backup:=expandwork(dir_backup,true);
  dir_bad:=expandwork(dir_bad,true);
  dir_canada:=expandwork(dir_canada,true);
  dir_china:=expandwork(dir_china,true);
  dir_dupes:=expandwork(dir_dupes,true);
  dir_europe:=expandwork(dir_europe,true);
  dir_gamehacks:=expandwork(dir_gamehacks,true);
  dir_hacked:=expandwork(dir_hacked,true);
  dir_japan:=expandwork(dir_japan,true);
  dir_maphacks:=expandwork(dir_maphacks,true);
  dir_pc10:=expandwork(dir_pc10,true);
  dir_pirate:=expandwork(dir_pirate,true);
  dir_repair:=expandwork(dir_repair,true);
  dir_sweden:=expandwork(dir_sweden,true);
  dir_trans:=expandwork(dir_trans,true);
  dir_unknown:=expandwork(dir_unknown,true);
  dir_unlicensed:=expandwork(dir_unlicensed,true);
  dir_usa:=expandwork(dir_usa,true);
  dir_vs:=expandwork(dir_vs,true);
  if dir_savestates<>'' then dir_savestates:=expandwork(dir_savestates,true);
end;

procedure loadcfgfile;
var
  f:text;
  s,s2:string;
  p:integer;
  rp:boolean;
begin
  rp:=true;
  assign(f,progpath+cfgfile);
  {$I-}
  reset(f);
  {$I+}
  if ioresult>0 then
    begin
      rewrite(f);
      writeln(f,'DIR_BASE = ',dir_base);
      writeln(f,'DIR_BACKUP = ',dir_backup);
      writeln(f,'DIR_BAD = ',dir_bad);
      writeln(f,'DIR_CANADA = ',dir_canada);
      writeln(f,'DIR_CHINA = ',dir_china);
      writeln(f,'DIR_DUPLICATES = ',dir_dupes);
      writeln(f,'DIR_EUROPE = ',dir_europe);
      writeln(f,'DIR_GAMEHACKS = ',dir_gamehacks);
      writeln(f,'DIR_HACKED = ',dir_hacked);
      writeln(f,'DIR_JAPAN = ',dir_japan);
      writeln(f,'DIR_MAPHACKS = ',dir_maphacks);
      writeln(f,'DIR_PC10 = ',dir_pc10);
      writeln(f,'DIR_PIRATE = ',dir_pirate);
      writeln(f,'DIR_SWEDEN = ',dir_sweden);
      writeln(f,'DIR_TRANS = ',dir_trans);
      writeln(f,'DIR_UNKNOWN = ',dir_unknown);
      writeln(f,'DIR_UNLICENSED = ',dir_unlicensed);
      writeln(f,'DIR_USA = ',dir_usa);
      writeln(f,'DIR_VS = ',dir_vs);
      writeln(f,'DIR_SAVESTATES = ',dir_savestates);
      writeln(f);
      writeln(f,'MOVE_BAD = ',move_bad);
      writeln(f,'MOVE_HACKED = ',move_hacked);
      writeln(f,'MOVE_PIRATE = ',move_pirate);
      writeln(f);
      writeln(f,'MISSING_BAD = ',missing_bad);
      writeln(f,'MISSING_GAMEHACKS = ',missing_gamehacks);
      writeln(f,'MISSING_HACKED = ',missing_hacked);
      writeln(f,'MISSING_PIRATE = ',missing_pirate);
      writeln(f,'MISSING_TRANS = ',missing_trans);
      writeln(f);
      writeln(f,'FILE_MISSING = ',missingfile);
      writeln(f,'SHORT_NAMES = ',shortname);
      writeln(f,'WIN2000 = ',win2000);
      writeln(f);
      writeln(f,'CMDLINE =');
      close(f);
    end else
    begin
      while not eof(f) do
        begin
          readln(f,s);
          s:=removecomment(s);
          p:=pos('=',s);
          if p>0 then
            begin
              s2:=copy(s,p+1,length(s)-p);
              s:=copy(s,1,p-1);
              s:=removespaces(s,true);
              s:=upcasestr(s);
              if s='CMDLINE' then rp:=false;
              s2:=removespaces(s2,rp);
              if copy(s,1,4)='DIR_' then
                if (s2<>'') and (s2[length(s2)]<>'\') then s2:=s2+'\';
              if s='DIR_BASE' then dir_base:=s2;
              if s='DIR_BACKUP' then dir_backup:=s2;
              if s='DIR_BAD' then dir_bad:=s2;
              if s='DIR_CANADA' then dir_canada:=s2;
              if s='DIR_CHINA' then dir_china:=s2;
              if s='DIR_DUPLICATES' then dir_dupes:=s2;
              if s='DIR_EUROPE' then dir_europe:=s2;
              if s='DIR_GAMEHACKS' then dir_gamehacks:=s2;
              if s='DIR_JAPAN' then dir_japan:=s2;
              if s='DIR_MAPHACKS' then dir_maphacks:=s2;
              if s='DIR_PC10' then dir_pc10:=s2;
              if s='DIR_PIRATE' then dir_pirate:=s2;
              if s='DIR_SWEDEN' then dir_sweden:=s2;
              if s='DIR_HACKED' then dir_hacked:=s2;
              if s='DIR_TRANS' then dir_trans:=s2;
              if s='DIR_UNKNOWN' then dir_unknown:=s2;
              if s='DIR_UNLICENSED' then dir_unlicensed:=s2;
              if s='DIR_USA' then dir_usa:=s2;
              if s='DIR_VS' then dir_vs:=s2;
              if s='DIR_SAVESTATES' then dir_savestates:=s2;
              if s='FILE_MISSING' then missingfile:=s2;
              if s='SHORT_NAMES' then if upcasestr(s2)='FALSE' then shortname:=false else
                if upcasestr(s2)='TRUE' then shortname:=true;
              if s='WIN2000' then if upcasestr(s2)='FALSE' then win2000:=false else
                if upcasestr(s2)='TRUE' then win2000:=true;
              if s='MOVE_BAD' then if upcasestr(s2)='FALSE' then move_bad:=false else
                if upcasestr(s2)='TRUE' then move_bad:=true;
              if s='MOVE_HACKED' then if upcasestr(s2)='FALSE' then move_hacked:=false else
                if upcasestr(s2)='TRUE' then move_hacked:=true;
              if s='MOVE_PIRATE' then if upcasestr(s2)='FALSE' then move_pirate:=false else
                if upcasestr(s2)='TRUE' then move_pirate:=true;
              if s='MISSING_BAD' then if upcasestr(s2)='FALSE' then missing_bad:=false else
                if upcasestr(s2)='TRUE' then missing_bad:=true;
              if s='MISSING_GAMEHACKS' then if upcasestr(s2)='FALSE' then missing_gamehacks:=false else
                if upcasestr(s2)='TRUE' then missing_gamehacks:=true;
              if s='MISSING_HACKED' then if upcasestr(s2)='FALSE' then missing_hacked:=false else
                if upcasestr(s2)='TRUE' then missing_hacked:=true;
              if s='MISSING_PIRATE' then if upcasestr(s2)='FALSE' then missing_pirate:=false else
                if upcasestr(s2)='TRUE' then missing_pirate:=true;
              if s='MISSING_TRANS' then if upcasestr(s2)='FALSE' then missing_trans:=false else
                if upcasestr(s2)='TRUE' then missing_trans:=true;
              if s='CMDLINE' then cfgparam:=s2;
            end;
        end;
      close(f);
    end;
    expandpaths;
end;

procedure loaddbase;
var
  f:text;
  s:string;
  cs:array[0..8] of char;
  csprg:array[0..13] of char;
  p,code:integer;
begin
  dbasecount:=0;
  FCCount:=0;
  assign(f,progpath+dbasefile);
  {$I-}
  reset(f);
  {I+}
  if ioresult>0 then
    begin
      rewrite(f);
      reset(f);
    end;
  while not eof(f) do
    begin
      dbasecount:=dbasecount+1;
      readln(f,s);
      strpcopy(cs,copy(s,1,8));
      csumdbase[dbasecount].str:=strnew(cs);
      csumdbase[dbasecount].flag:=false;
      csumdbase[dbasecount].resize:=0;
      strpcopy(csprg,copy(s,10,8)+i2s(dbasecount,0));
      prgdbase[dbasecount]:=strnew(csprg);
      if s[18]='*' then
        begin
          fccount:=fccount+1;
          csumdbase[dbasecount].resize:=fccount;
          p:=pos(';',s); delete(s,1,p);
          p:=pos(';',s); delete(s,1,p);
          p:=pos(';',s); val(copy(s,1,p-1),FCPrg[fccount],code); delete(s,1,p);
          p:=pos(';',s); val(copy(s,1,p-1),FCChr[fccount],code); delete(s,1,p);
        end;
    end;
  close(f);
  quicksort(prgdbase,1,dbasecount);
end;

procedure dbaseclose;
var
  counter:integer;
begin
  for counter:=dbasecount downto 1 do
    begin
      strdispose(prgdbase[counter]);
      strdispose(csumdbase[counter].str);
    end;
end;


function formatoutput(fname:string;minfo:neshdr;docsum:boolean;csum:string;rflag:integer;l:integer;view_bl:boolean):string;
var
  out:string;
  ns:string;
  split:boolean;
  fname2:string;
  c:char;
  count:integer;
  ctemp:integer;
begin
  out:='';
  split:=false;
  if length(fname)>l then
    begin
      count:=l;
      split:=true;
      repeat
        c:=fname[count];
        count:=count-1;
      until (c=' ') or (c='_') or (count=0);
      if count=0 then split:=false;
      if split=true then
        begin
          fname2:=copy(fname,count+2,length(fname)-count-1);
          delete(fname,count+1,length(fname)-count);
        end;
    end;
  str(minfo.mapper,ns);
  if rflag=0 then out:=out+'  ';
  if rflag=1 then out:=out+'? ';
  if rflag=2 then out:=out+'* ';
  if rflag=3 then out:=out+'x ';
  if rflag=4 then out:=out+'n ';
  if rflag=5 then out:=out+'d ';
  if rflag=6 then out:=out+'b ';
  out:=out+justify(fname,l,'L',true);
  out:=out+' '+justify(ns,3,'R',False)+' ';
  if minfo.mirror=0 then out:=out+'H' else out:=out+'V';
  if minfo.sram=0 then out:=out+'.' else out:=out+'B';
  if minfo.trainer=0 then out:=out+'.' else out:=out+'T';
  if minfo.fourscr=0 then out:=out+'.' else out:=out+'4';
  if view_bl=false then
    begin
      str(minfo.prg*16,ns);
      out:=out+' '+justify(ns,4,'R',False)+'kB';
      if minfo.chr>0 then
        begin
          str(minfo.chr*8,ns);
          out:=out+' '+justify(ns,4,'R',False)+'kB';
        end else out:=out+'  -----';
    end else
    begin
      str(minfo.prg,ns);
      out:=out+' '+justify(ns,2,'R',False)+'x16kB';
      if minfo.chr>0 then
        begin
          str(minfo.chr,ns);
          out:=out+' '+justify(ns,2,'R',False)+'x8kB';
        end else out:=out+'  -----';
    end;
  if docsum=true then
    begin
      ctemp:=minfo.country mod 1024;
      if ctemp=0 then out:=out+' ???';
      if ctemp=1 then out:=out+' '+'J  ';
      if ctemp=2 then out:=out+' '+' U ';
      if ctemp=3 then out:=out+' '+'JU ';
      if ctemp=4 then out:=out+' '+'  E';
      if ctemp=5 then out:=out+' '+'J E';
      if ctemp=6 then out:=out+' '+' UE';
      if ctemp=7 then out:=out+' '+'JUE';
      if ctemp=8 then out:=out+' '+'  S';
      if ctemp=16 then out:=out+' '+' F ';
      if ctemp=32 then out:=out+' '+'C  ';
      if ctemp=64 then out:=out+' '+'Unl';
      if ctemp=128 then out:=out+' '+'VS ';
      if ctemp=256 then out:=out+' '+'P10';
      if ctemp=512 then out:=out+' '+'TR ';
    end;
  if docsum=true then out:=out+' '+csum;
  if split=true then out:=out+#27+'     '+fname2;
  formatoutput:=out;
end;

procedure checksplit(var s1:string;var s2:string);
var
  p:integer;
begin
  s2:='';
  p:=pos(#27,s1);
  if p>0 then
    begin
      s2:=copy(s1,p+1,length(s1)-p);
      delete(s1,p,length(s1)-p+1);
    end;
end;


function comparehdrs(rh:neshdr;dh:neshdr):boolean;
var
  tbool:boolean;
begin
  tbool:=true;
  if rh.hdr<>dh.hdr then tbool:=false;
  if rh.prg<>dh.prg then tbool:=false;
  if rh.chr<>dh.chr then tbool:=false;
  if rh.mirror<>dh.mirror then tbool:=false;
  if rh.sram<>dh.sram then tbool:=false;
  if rh.trainer<>dh.trainer then tbool:=false;
  if rh.fourscr<>dh.fourscr then tbool:=false;
  if rh.mapper<>dh.mapper then tbool:=false;
  if rh.vs<>dh.vs then tbool:=false;
  if rh.pc10<>dh.pc10 then tbool:=false;
  if rh.other<>dh.other then tbool:=false;
  comparehdrs:=tbool;
end;

procedure parsemissing(missingpath:string);
var
  f2:text;
  flags:array[1..maxdbasesize] of boolean;
  ctr,result:integer;
  s:string;
begin
  for ctr:=1 to dbasecount do
    flags[ctr]:=false;
  assign(f2,missingpath);
  reset(f2);
  while not eof(f2) do
    begin
      readln(f2,s);
      while s[length(s)]=' ' do delete(s,length(s),1);
      s:=copy(s,length(s)-7,8);
      searchdbase(s,result);
      if result>0 then flags[result]:=true;
    end;
  close(f2);
  for ctr:=1 to dbasecount do
    if flags[ctr]=false then csumdbase[ctr].flag:=true;
end;

function shortparse(name:string;shorten:boolean):string;
var
  p,p2:integer;
begin
  p:=pos('<',name);
  p2:=pos('>',name);
  while (p>0) and (p2>p) do
    begin
      delete(name,p2,1);
      delete(name,p,1);
      if shorten=true then
        delete(name,p,p2-p-1);
      p:=pos('<',name);
      p2:=pos('>',name);
    end;
  shortparse:=name;
end;

function fixperiod(name:string):string;
var
  p:integer;
begin
  p:=pos('.',name);
  while p>0 do
    begin
      if (copy(name,p+1,1)<'0') or (copy(name,p+1,1)>'9')
        then delete(name,p,1)
        else name[p]:='_';
      p:=pos('.',name);
    end;
  fixperiod:=name;
end;

procedure listmissing(showall,csort:boolean);
var
  f,f2:text;
  io,io2,c,x,p,code,acount:integer;
  counter:integer;
  badcount:integer;
  byte7,byte8:byte;
  ts,ts2,fn,out,out2:string;
  dbaseinfo:neshdr;
  csum:string[8];
  dbasearray:array[1..maxdbasesize] of pchar;
  charout:array[0..255] of char;
  missingpath:string;
  missingtemp:string;
  country:string[3];
  skipflag:boolean;

begin
  acount:=0;
  badcount:=0;
  missingpath:=getshortpathname(cpath,false);
  missingtemp:=missingpath+'TEMP$.$$$';
  missingpath:=missingpath+missingfile;
  if exist(missingtemp) then LFNErase(missingtemp,FA_NORMAL,FA_NORMAL,false);
  LFNRename(missingpath,missingtemp);
  assign(f2,missingtemp);
  {$I-}
  if overwritemissing=true then rewrite(f2) else
    begin
      reset(f2);
      io:=ioresult;
      if io>0 then rewrite(f2) else
        begin
          close(f2);
          parsemissing(missingtemp);
          rewrite(f2);
        end;
    end;
  io2:=ioresult;
  {$I+}
  if io2=0 then
    begin
      assign(f,progpath+dbasefile);
      reset(f);
      for c:=1 to dbasecount do
        begin
          readln(f,ts);
          p:=pos(';',ts); csum:=copy(ts,1,p-1); delete(ts,1,p);
          p:=pos(';',ts); delete(ts,1,p);
          p:=pos(';',ts);
          if p=0 then fn:=ts else
            begin
              fn:=copy(ts,1,p-1);
              delete(ts,1,p);
            end;
          fn:=shortparse(fn,false);
          p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); byte7:=x;
          p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); byte8:=x;
          p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); dbaseinfo.prg:=x;
          p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); dbaseinfo.chr:=x;
          p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
          dbaseinfo.country:=countrys2i(ts2);
          p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
          dbaseinfo.company:=ts2;
          skipflag:=false;
          if (dbaseinfo.country div 16384=1) and (missing_bad=false) then skipflag:=true;
          if (dbaseinfo.country mod 1024 div 512=1) and (missing_trans=false) then skipflag:=true;
          if (dbaseinfo.country mod 2048 div 1024=1) and (missing_pirate=false) then skipflag:=true;
          if (dbaseinfo.country mod 4096 div 2048=1) and (missing_hacked=false) then skipflag:=true;
          if (dbaseinfo.country mod 8192 div 4096=1) and (missing_gamehacks=false) then skipflag:=true;
          if (dbaseinfo.country mod 16384 div 8192=1) and (missing_hacked=false) then skipflag:=true;
          if csumdbase[c].resize>0 then skipflag:=true;
          if skipflag=true then badcount:=badcount+1;
          if (csumdbase[c].flag=false) and (skipflag=false) then
            begin
              acount:=acount+1;
              dbaseinfo.mirror:=byte7 mod 2;
              dbaseinfo.sram:=byte7 div 2 mod 2;
              dbaseinfo.trainer:=byte7 div 4 mod 2;
              dbaseinfo.fourscr:=byte7 div 8 mod 2;
              dbaseinfo.mapper:=byte7 div 16+byte8 div 16*16;
              dbaseinfo.vs:=byte8 mod 2;
              dbaseinfo.pc10:=byte8 div 2 mod 2;
              dbaseinfo.hdr:=hdrstring;
              dbaseinfo.other:=null8;
              out:=formatoutput(fn,dbaseinfo,true,csum,0,41,false);
              delete(out,1,2);
              country:=copy(out,66,3);
              if (csort=true) and (showall=true) then
                begin
                  delete(out,66,3);
                  out:=country+out;
                end;
              if showall=false then
                begin
                  if country='J E' then country:='JE ';
                  out:=fn+' ('+removespaces(country,true)+') - '+csum;
                end;
              if (csort=true) and (showall=false) then out:=country+out;
              for counter:=1 to length(out) do charout[counter-1]:=out[counter];
              charout[counter]:=#0;
              dbasearray[acount]:=strnew(charout);
            end;
        end;
      if acount>0 then quicksort(dbasearray,1,acount);
      if acount>0 then
        for c:=1 to acount do
          begin
            out2:='';
            out:=strpas(dbasearray[c]);
            if csort=true then
              begin
                country:=copy(out,1,3);
                delete(out,1,3);
                if showall=true then insert(country,out,66);
              end;
            if showall=true then checksplit(out,out2);
            writeln(f2,out);
            if out2<>'' then writeln(f2,out2);
          end;
      writeln(f2);
      writeln(f2,acount,' missing',sstr(' ROM',acount),' out of ',dbasecount-badcount);
      close(f);
      close(f2);
      if acount>0 then
        for c:=acount downto 1 do
           strdispose(dbasearray[c]);
      LFNRename(missingtemp,missingpath);
    end;
  if io2>0 then
    begin
      writeln;
      write('Error: Cannot create ',missingpath);
    end;
end;


function spcvt(o:string;i:integer):string;
var
  p:integer;
begin
  p:=pos(' ',o);
  while p>0 do
    begin
      if i=1 then o[p]:='_';
      if i=2 then delete(o,p,1);
      p:=pos(' ',o);
    end;
  spcvt:=o;
end;

procedure usage(t:byte);
begin
writeln('NesToy ',version,' - (c)2000, D-Tox Software  (BETA Software, Use At Own Risk)');
writeln;
if (t=0) or (t=1) then
  begin
    writeln('usage: NesToy [parameters] pathname1 [pathname2] [pathname3] ...');
    if t=0 then writeln;
    if t=0 then writeln('Type NesToy -help for command line parameters');
    if t=0 then writeln;
  end;
if t=1 then
  begin
    writeln('Parameters:');
    writeln('-b             Display PRG and CHR banks by # of blocks instead of kB');
    writeln('-c             Calculate Checksums (CRC 32)');
    writeln('-hc            Calculate Checksums with header');
    writeln('-i             Outputs extended info if header or name are not correct');
    writeln('-o[file]       Sends output to file (DOS 8.3 filenames for now)');
    writeln('-ren[uscltp]   Renames ROMs to names stored in database (enables -c)');
    writeln('                  u- Replace spaces with underscores');
    writeln('                  s- Remove spaces completely from filename');
    writeln('                  c- Attach country codes to end of filenames');
    writeln('                  l- Convert ROMs to all lowercase names');
    writeln('                  t- Places the word "The" at the beginning of ROM names');
    writeln('                     instead of at the end.');
    writeln('                  p- Use periods in appropriate ROM names (Warning: Nesticle');
    writeln('                     will not load ROMs with extra periods in them.');
    writeln('-rep,-repair   Repairs ROM headers with those found in database (enables -c)');
    writeln('-res,-resize   Automatically resizes ROMs if they contain duplicate or');
    writeln('               unused banks of data.');
    writeln('-sort[mt]       Sorts ROMs into directories by country or type');
    writeln('                  m- Sorts ROMs by mapper # as well');
    writeln('                  t- Sort Translations by country');
    pause;
    writeln('-m#            Filter listing by mapper #');
    writeln('-f[hvbt4]      Filter listing by mapper data');
    writeln('                  h- Horizontal Mirroring     t- Trainer Present');
    writeln('                  v- Vertical Mirroring       4- 4 Screen Buffer');
    writeln('                  b- Contains SRAM (Battery backup)');
    writeln('-u             Only display unknown ROMs (enables -c)');
    writeln('-sub           Process all subdirecories under directories specified on path');
    writeln('-missing[cbn]  Create a listing of missing ROMs.  If listing exists, it will be');
    writeln('               updated.  Filename is defined in ',cfgfile,'.');
    writeln('                  c- Sort missing list by country');
    writeln('                  b- Bare listing (Name, country codes, and checksum only)');
    writeln('                  n- Force NesToy to create a new missing list, even if one');
    writeln('                     already exists (It will be overwritten.)');
    writeln('-nobackup      Don''t make backups before repairing or resizing ROMs');
    writeln('-log           Log to ',logfile,' any problems NesToy encounters while sorting,');
    writeln('               renaming, or repairing ROMs.');
    writeln('-q[o]          Suppresses output to the screen (for those of you who would');
    writeln('               prefer not to see what NesToy is up to.)');
    writeln('                  o- Suppresses output to the output file as well.');
    writeln('-doall         Enables -c,-i,-ren,-repair,-resize,-sort, and -missing');
    writeln('-h,-?,-help    Displays this screen');
    writeln;
    writeln('Filename can include wildcards (*,?) anywhere inside the filename.  Long');
    writeln('file names are allowed.  If no filename is given, (*.nes) is assumed.');
    pause;
  end;
if t=2 then
  begin
    writeln('NesToy only runs under Windows 95/98/2000.');
    writeln;
    writeln('To run NesToy under Windows 2000, set WIN2000 in ',cfgfile,' to TRUE.');
    writeln;
    writeln('Warning: Setting WIN2000 to TRUE and then trying to run NesToy under DOS');
    writeln('         or under Windows NT will not work.  At the very least, NesToy may');
    writeln('         corrupt your precious ROMs.');
  end;
  dbaseclose;
  halt;
end;

var
  f,f2:word;
  dirinfo:tfinddata;
  attrib:word;
  h,ns,csum,prgcsum:string;
  clfname,pathname,sortdir:string;
  arraytemp:charstr;
  nes,oldnes,resulthdr:NesHdr;
  byte7,byte8:byte;
  l,ctr,csumpos,sps,err:integer;
  msearch,rflag,counter:integer;
  romcount,matchcount,rncount,rpcount,rscount,nomove,prgcount,dirromcount:integer;
  dbpos,io,pc,wy:integer;
  fcpos:integer;
  docsum,show,show_h,show_v,show_b,show_4,show_t,view_bl,outfile,extout,unknown:boolean;
  rname,namematch,dbase,extdbase,repair,cmp,abort,dbasemissing,garbage,sort,sortmapper,sorttrans:boolean;
  mthe,uscore,ccode,remspace,notrenamed,notrepaired,cropped,resize,sorted:boolean;
  booltemp,dupe,allmissing,missingsort,lowcasename,subdir:boolean;
  nobackup,badrom,mhackedrom,ghackedrom,hackedrom,piraterom,prgfound,remperiod:boolean;
  result,rtmp,rtmp2,ralt:string;
  key:char;
  out,out2:string;
  outm:string[13];
  ofile:text;
  errcode:word;
  name:string;
  newprg,newchr:byte;
  sortcode:integer;
  filedt:NewDateTime;
  hour,min,sec,hund:word;
  Year,Month,Day,DOW:word;
  fullstarttime,fullendtime,difftime,temptime:longint;
  fs:integer;

begin
  checkbreak:=false;
  cfgparam:='';
  progpath:=paramstr(0);
  while copy(progpath,length(progpath),1)<>'\' do
    delete(progpath,length(progpath),1);
  loadcfgfile;
  if (IsDOS70=false) and (win2000=false) then usage(2);
  loaddbase;
  extparamst:=paramstrparse;
  cpath:=getfullpathname('.\',false);
  pathname:='';
  out2:='';
  view_bl:=false;
  show_h:=false;
  show_v:=false;
  show_b:=false;
  show_t:=false;
  show_4:=false;
  outfile:=false;
  extout:=false;
  numpaths:=0;
  romcount:=0;
  matchcount:=0;
  rncount:=0;
  rpcount:=0;
  rscount:=0;
  nomove:=0;
  prgcount:=0;
  docsum:=false;
  hdcsum:=false;
  rname:=false;
  mthe:=false;
  uscore:=false;
  ccode:=false;
  remspace:=false;
  remperiod:=true;
  unknown:=false;
  dbase:=false;
  extdbase:=false;
  repair:=false;
  resize:=false;
  abort:=false;
  dbasemissing:=false;
  sort:=false;
  sortmapper:=false;
  sorttrans:=false;
  dupe:=false;
  allmissing:=true;
  missingsort:=false;
  lowcasename:=false;
  overwritemissing:=false;
  subdir:=false;
  nobackup:=false;
  logging:=false;
  quiet:=false;
  outquiet:=false;
  msearch:=-1;
  if extparamcount=0 then usage(0);
  searchps('-h',sps,result);
  if sps>0 then usage(1);
  searchps('-?',sps,result);
  if sps>0 then usage(1);
  searchps('-help',sps,result);
  if sps>0 then usage(1);
  searchps('-sub',sps,result);
  if sps>0 then subdir:=true;
  for pc:=1 to extparamcount+1 do
    begin
      if pc>extparamcount then
        begin
          if numpaths=0 then clfname:='*.nes' else clfname:='-';
        end else clfname:=extparamstr(pc);
      if (clfname[1]<>'-') and (numpaths<maxpathnames) then
        begin
          splitpath(clfname,clfname,pathname);
          pathname:=getfullpathname(pathname,false);
          if clfname='' then clfname:='*.nes';
          if subdir=true then
            begin
              f2:=lfnfindfirst(pathname+'*.*',FA_DIR,FA_DIR,dirinfo);
              while (dos7error=0) and (numpaths<maxpathnames) do
                begin
                  if (dirinfo.name<>'.') and (dirinfo.name<>'..') then
                    if (upcasestr(pathname+dirinfo.name+'\')<>upcasestr(dir_dupes)) and
                       (upcasestr(pathname+dirinfo.name+'\')<>upcasestr(dir_backup)) then
                      begin
                        numpaths:=numpaths+1;
                        str2chr(clfname,arraytemp);
                        clf[numpaths]:=strnew(arraytemp);
                        str2chr(pathname+dirinfo.name+'\',arraytemp);
                        path[numpaths]:=strnew(arraytemp);
                      end;
                  lfnfindnext(f2,dirinfo);
                end;
              lfnfindclose(f2);
            end;
          numpaths:=numpaths+1;
          str2chr(clfname,arraytemp);
          clf[numpaths]:=strnew(arraytemp);
          str2chr(pathname,arraytemp);
          path[numpaths]:=strnew(arraytemp);
        end;
    end;
  searchps('-c',sps,result);
  if sps>0 then docsum:=true;
  searchps('-hc',sps,result);
  if sps>0 then begin docsum:=true; hdcsum:=true; end;
  searchps('-m#',sps,result);
  if sps>0 then
    begin
      val(result,msearch,err);
      if err<>0 then msearch:=-1;
    end;
  searchps('-b',sps,result);
  if sps>0 then view_bl:=true;
  searchps('-f*',sps,result);
  if sps>0 then
    begin
      if pos('H',result)>0 then show_h:=true;
      if pos('V',result)>0 then show_v:=true;
      if pos('B',result)>0 then show_b:=true;
      if pos('T',result)>0 then show_t:=true;
      if pos('4',result)>0 then show_4:=true;
    end;
  searchps('-ren*',sps,result);
  if sps>0 then
    begin
      rname:=true; docsum:=true;
      if pos('U',result)>0 then uscore:=true;
      if pos('S',result)>0 then remspace:=true;
      if pos('C',result)>0 then ccode:=true;
      if pos('L',result)>0 then lowcasename:=true;
      if pos('T',result)>0 then mthe:=true;
      if pos('P',result)>0 then remperiod:=false;
    end;
  searchps('-o*',sps,result);
  if sps>0 then
    begin
      outfile:=true;
      if result='' then result:=outputfile;
      result:=getshortpathname(cpath,false)+result;
      assign(ofile,result);
      {$I-}
      reset(ofile);
      io:=ioresult;
      if io>0 then rewrite(ofile) else append(ofile);
      if ioresult>0 then
        begin
          write('Error: Cannot create ',result);
          halt;
        end;
      {$I+}
      if io=0 then begin
                     writeln(ofile);
                     writeln(ofile,'------------------------------------------------------------------------------');
                   end;
    end;
  searchps('-log',sps,result);
  if sps>0 then
    begin
      logging:=true;
      wrotelog:=false;
      result:=logfile;
      result:=getshortpathname(cpath,false)+result;
      assign(lfile,result);
      {$I-}
      reset(lfile);
      io:=ioresult;
      if io>0 then rewrite(lfile) else append(lfile);
      if ioresult>0 then
        begin
          write('Error: Cannot create ',result);
          halt;
        end;
      {$I+}
    end;
  searchps('-rep',sps,result);
  if sps>0 then begin repair:=true; extout:=true; docsum:=true end;
  searchps('-repair',sps,result);
  if sps>0 then begin repair:=true; extout:=true; docsum:=true end;
  searchps('-res',sps,result);
  if sps>0 then begin resize:=true; extout:=true; docsum:=true; end;
  searchps('-resize',sps,result);
  if sps>0 then begin resize:=true; extout:=true; docsum:=true; end;
  searchps('-u',sps,result);
  if sps>0 then begin unknown:=true; docsum:=true; end;
  searchps('-nobackup',sps,result);
  if sps>0 then nobackup:=true;
  searchps('-missing*',sps,result);
  if sps>0 then
    begin
      dbasemissing:=true;
      docsum:=true;
      if pos('C',result)>0 then missingsort:=true;
      if pos('B',result)>0 then allmissing:=false;
      if pos('N',result)>0 then overwritemissing:=true;
    end;
  searchps('-sort*',sps,result);
  if sps>0 then
    begin
      sort:=true; docsum:=true;
      if pos('M',result)>0 then sortmapper:=true;
      if pos('T',result)>0 then sorttrans:=true;
    end;
  searchps('-doall',sps,result);
  if sps>0 then begin
                  docsum:=true; rname:=true; repair:=true; resize:=true; extout:=true;
                  dbasemissing:=true; sort:=true;
                end;
  searchps('-q*',sps,result);
  if sps>0 then
    begin
      quiet:=true; extout:=false;
      if pos('O',result)>0 then outquiet:=true;
    end;
  searchps('-i',sps,result);
  if sps>0 then begin extout:=true; docsum:=true; end;
  searchps('-dbase',sps,result);
  if sps>0 then begin
                  dbase:=true; docsum:=true; extout:=false; sort:=false; unknown:=false;
                  rname:=false; repair:=false; resize:=false; dbasemissing:=false;
                end;
  searchps('-dbase2',sps,result);
  if sps>0 then begin
                  dbase:=true; docsum:=true; extout:=false; sort:=false; unknown:=false;
                  rname:=false; repair:=false; resize:=false; dbasemissing:=false;
                  extdbase:=true;
                end;
  if docsum=false then l:=55 else l:=40;
  gettime(hour,min,sec,hund);
  getdate(Year,Month,Day,DOW);
  fullstarttime:=sec+min*60+hour*3600;
  for pc:=1 to numpaths do
    if abort=false then
    begin
      dirromcount:=0;
      pathname:=strpas(path[pc]);
      clfname:=strpas(clf[pc]);
      writeln;
      if outfile=true then writeln(ofile);
      write(pathname,clfname);
      if outfile=true then write(ofile,pathname,clfname);
      LFNChDir(pathname);
      if dos7Error=3 then
        begin
          writeln(' [Path Not Found]');
          if outfile=true then writeln(ofile,' [Path Not Found]');
        end;
      if Dos7Error=0 then
      begin
        writeln;
        if outfile=true then writeln(ofile);
        if quiet=true then begin writeln; wy:=wherey-1; end;
        f:=readdir(clfname);
        for counter:=1 to f do
          if abort=false then
          begin
            name:=strpas(dirarray[counter]);
            out:='';
            if keypressed=true then
              begin
                key:=readkey;
                if key=#27 then abort:=true;
              end;
            show:=true;
            garbage:=false;
            dupe:=false;
            notrenamed:=false;
            notrepaired:=false;
            cropped:=false;
            badrom:=false;
            mhackedrom:=false;
            ghackedrom:=false;
            hackedrom:=false;
            piraterom:=false;
            sorted:=false;
            flagrom:=true;
            prgfound:=false;
            fcpos:=0;
            h:=ReadNesHdr(Name);
            attrib:=LFNGetAttrib(Name);
            if (attrib and fa_rdonly)=1 then
              begin
                if attrib<32 then attrib:=attrib+32;
                LFNSetAttrib(Name,attrib-1);
              end;
            getneshdr(nes,h);
            if nes.hdr<>hdrstring then show:=false;
            if msearch>-1 then if nes.mapper<>msearch then show:=false;
            if (show_h=true) and (nes.mirror=1) then show:=false;
            if (show_v=true) and (nes.mirror=0) then show:=false;
            if (show_b=true) and (nes.sram=0) then show:=false;
            if (show_t=true) and (nes.trainer=0) then show:=false;
            if (show_4=true) and (nes.fourscr=0) then show:=false;
            if (docsum=true) and (show=true) then
              begin
                getcrc(Name,csum,prgcsum,garbage,nes.prg);
                searchdbase(csum,dbpos);
                if resize=true then
                  begin
                    if (dbpos>0) and (csumdbase[dbpos].resize>0) then
                      begin
                        fcpos:=csumdbase[dbpos].resize;
                        dbpos:=0;
                      end;
                    if dbpos=0 then
                      begin
                        fs:=romsize(name);
                        if FCPos=0 then checkbanks(Name,nes.prg,nes.chr,newprg,newchr);
                        if FCPos>0 then begin newprg:=fcprg[fcpos]; newchr:=fcchr[fcpos]; end;
                        if (nes.prg<>newprg) or (nes.chr<>newchr) or (fs>nes.prg*2+nes.chr) then
                          begin
                            oldnes:=nes;
                            CropRom(Name,nes,nes.prg,nes.chr,newprg,newchr,errcode);
                            if errcode=0 then
                              begin
                                if copy(name,length(name)-3,1)='.' then rtmp:=copy(name,1,length(name)-4);
                                if nobackup=true then
                                  LFNErase(rtmp+'.ba~',FA_NORMAL,FA_NORMAL,false) else
                                  LFNMove(rtmp+'.ba~',dir_backup+rtmp+'.bak','','',errcode);
                                rscount:=rscount+1;
                                cropped:=true;
                                getcrc(Name,csum,prgcsum,garbage,nes.prg);
                                searchdbase(csum,dbpos);
                              end else notrepaired:=true;
                          end;
                      end;
                  end;
                if dbpos=0 then
                  begin
                    if (nes.prg<>0) and (nes.prg<>1) and (nes.prg<>2) and (nes.prg<>4) and
                       (nes.prg<>8) and (nes.prg<>16) and (nes.prg<>32) and (nes.prg<>40) and
                       (nes.prg<>64) and (nes.prg<>96) and (nes.prg<>128) then badrom:=true;
                    if (nes.chr<>0) and (nes.chr<>1) and (nes.chr<>2) and (nes.chr<>4) and
                       (nes.chr<>8) and (nes.chr<>16) and (nes.chr<>32) and (nes.chr<>64) and
                       (nes.chr<>128) then badrom:=true;
                    fs:=romsize(name);
                    if fs<nes.prg*2+nes.chr then badrom:=true;
                  end;
                if dbpos=0 then
                  begin
                    searchprgdbase(prgcsum,dbpos);
                    if dbpos>0 then begin prgfound:=true; badrom:=true; prgcount:=prgcount+1; end;
                  end;
                if (dbpos>0) and (prgfound=false) then
                  begin
                    if csumdbase[dbpos].flag=true then
                      begin
                        if sort=true then
                          begin
                            LFNGetModifTime(Name,FileDT);
                            temptime:=FileDT.second+FileDT.minute*60+FileDT.hour*3600;
                            if FileDT.year<year then dupe:=true;
                            if (FileDT.year=year) and (FileDT.month<month) then dupe:=true;
                            if (FileDT.year=year) and (FileDT.month=month) and (FileDT.day<day) then dupe:=true;
                            if (FileDT.year=year) and (FileDT.month=month) and (FileDT.day=day)
                              then if temptime<fullstarttime-5 then dupe:=true;
                          end else dupe:=true;
                      end;
                  end;
                if unknown=true then show:=false;
                if (unknown=true) and (dbpos=0) then show:=true;
              end;
            if show=true then
              begin
                if docsum=true then rflag:=1 else rflag:=-1;
                romcount:=romcount+1;
                dirromcount:=dirromcount+1;
                if (dbpos=0) and (badrom=true) then rflag:=6;
                if (dbpos>0) and (dbase=false) then
                  begin
                    rflag:=2;
                    if prgfound=false then matchcount:=matchcount+1;
                    getdbaseinfo(dbpos,result,resulthdr);
                    result:=shortparse(result,shortname);
                    if prgfound=true then
                      begin
                        result:=result+badchr+' '+csum+')';
                        resulthdr.chr:=nes.chr;
                      end;
                    if (resulthdr.vs=1) and (resulthdr.pc10=1) then
                      begin
                        writeln('ERROR IN DATABASE 01 -- ',strpas(csumdbase[dbpos].str),' ',result);
                        halt;
                      end;
                    nes.country:=resulthdr.country;
                    nes.company:=resulthdr.company;
                    if nes.country mod 2048 div 1024=1 then piraterom:=true;
                    if nes.country mod 4096 div 2048=1 then mhackedrom:=true;
                    if nes.country mod 8192 div 4096=1 then ghackedrom:=true;
                    if nes.country mod 16384 div 8192=1 then hackedrom:=true;
                    if nes.country div 16384=1 then badrom:=true;
                    if mthe=true then result:=movethe(result);
                    if ccode=true then result:=result+countryi2s(nes.country);
                    if lowcasename=true then result:=lowcasestr(result);
                    if remspace=true then result:=spcvt(result,2);
                    if uscore=true then result:=spcvt(result,1);
                    if remperiod=true
                     then begin
                            ralt:=result;
                            result:=fixperiod(result);
                          end else ralt:=fixperiod(result);
                    cmp:=comparehdrs(nes,resulthdr);
                    if result+'.nes'<>name then namematch:=false else namematch:=true;
                    if (namematch=false) and (rname=false) then
                      begin
                        rtmp:=result;
                        if rtmp[length(rtmp)]='.' then rtmp:=rtmp+'nes' else rtmp:=rtmp+'.nes';
                        rtmp2:=ralt;
                        if rtmp2[length(rtmp2)]='.' then rtmp2:=rtmp2+'nes' else rtmp2:=rtmp2+'.nes';
                        if mthe=false then
                          if lowcasestr(copy(name,1,3))='the' then
                            begin rtmp:=movethe(rtmp); rtmp2:=movethe(rtmp2); end;
                        if name=lowcasestr(name) then
                          begin rtmp:=lowcasestr(rtmp); rtmp2:=lowcasestr(rtmp2); end;
                        if (rtmp=name) or (rtmp2=name) then namematch:=true else
                        if (spcvt(rtmp,1)=name) or (spcvt(rtmp2,1)=name) then namematch:=true else
                        if (spcvt(rtmp,2)=name) or (spcvt(rtmp2,2)=name) then namematch:=true else
                          begin
                            rtmp:=result+countryi2s(nes.country);
                            if rtmp[length(rtmp)]='.' then rtmp:=rtmp+'nes' else rtmp:=rtmp+'.nes';
                            rtmp2:=ralt+countryi2s(nes.country);
                            if rtmp2[length(rtmp2)]='.' then rtmp2:=rtmp2+'nes' else rtmp2:=rtmp2+'.nes';
                            if mthe=false then
                              if lowcasestr(copy(name,1,3))='the' then
                                begin rtmp:=movethe(rtmp); rtmp2:=movethe(rtmp2); end;
                            if name=lowcasestr(name) then
                              begin rtmp:=lowcasestr(rtmp); rtmp2:=lowcasestr(rtmp2); end;
                            if (rtmp=name) or (rtmp2=name) then namematch:=true else
                            if (spcvt(rtmp,1)=name) or (spcvt(rtmp2,1)=name) then namematch:=true else
                            if (spcvt(rtmp,2)=name) or (spcvt(rtmp2,2)=name) then namematch:=true
                          end;
                      end;
                    if result[length(result)]='.' then delete(result,length(result),1);
                    if badrom=true then rflag:=6;
                    if namematch=false then rflag:=4;
                    if (cmp=false) or (garbage=true) then rflag:=3;
                    if dupe=true then rflag:=5;
                  end;
                if dbase=false
                  then
                    begin
                      if cropped=true then
                        begin
                          if (quiet=false) or (extout=true) then
                            begin
                              out:=formatoutput(name,oldnes,docsum,' Resized',1,l,view_bl);
                              checksplit(out,out2);
                              if quiet=true then gotoxy(1,wy);
                              writeln(out);
                              if out2<>'' then writeln(out2);
                              if quiet=true then
                                begin
                                  if wy=24 then writeln;
                                  if wy<24 then wy:=wherey;
                                end;
                            end;
                          if (outfile=true) and ((extout=true) or (outquiet=false)) then
                            begin
                              writeln(ofile,out);
                              if out2<>'' then writeln(ofile,out2);
                            end;
                        end;
                      out:=formatoutput(name,nes,docsum,csum,rflag,l,view_bl);
                      checksplit(out,out2);
                    end
                  else
                    if extdbase=false then
                      begin
                        out:=out+csum+';'+prgcsum+';'+name;
                        if copy(out,length(out)-3,1)='.' then out:=copy(out,1,length(out)-4);
                        byte7:=nes.mirror+nes.sram*2+nes.trainer*4+nes.fourscr*8+nes.mapper mod 16*16;
                        byte8:=nes.vs+nes.pc10*2+nes.mapper div 16*16;
                        out:=out+';'+i2s(byte7,0);
                        out:=out+';'+i2s(byte8,0);
                        out:=out+';'+i2s(nes.prg,0);
                        out:=out+';'+i2s(nes.chr,0);
                      end else
                      begin
                        out:=out+'"'+csum+'","'+name;
                        if copy(out,length(out)-3,1)='.' then out:=copy(out,1,length(out)-4);
                        out:=out+'"';
                        out:=out+','+i2s(nes.mapper,0)+',';
                        out:=out+i2s(nes.mirror,0)+','+i2s(nes.sram,0)+',';
                        out:=out+i2s(nes.trainer,0)+','+i2s(nes.fourscr,0)+',"';
                        if nes.mirror=1 then out:=out+'V' else out:=out+'H';
                        if nes.sram=1 then out:=out+'B' else out:=out+'.';
                        if nes.trainer=1 then out:=out+'T' else out:=out+'.';
                        if nes.fourscr=1 then out:=out+'4' else out:=out+'.';
                        out:=out+'",'+i2s(nes.prg,0)+','+i2s(nes.chr,0);
                      end;
                sortcode:=nes.country;
                if (piraterom=true) and (move_pirate=true) then sortcode:=-5;
                if (mhackedrom=true) and (move_hacked=true) then sortcode:=-4;
                if ghackedrom=true then sortcode:=-3;
                if (hackedrom=true) and (move_hacked=true) then sortcode:=-2;
                if (badrom=true) and (move_bad=true) then sortcode:=-1;
                if (quiet=true) and (dbase=false) then
                  begin
                    gotoxy(1,wy);
                    writeln(dirromcount,' ROMs scanned.');
                  end else
                  begin
                    writeln(out);
                    if out2<>'' then writeln(out2);
                  end;
                if (outfile=true) and (outquiet=false) then
                  begin
                    writeln(ofile,out);
                    if out2<>'' then writeln(ofile,out2);
                  end;
                if (dbpos>0) and (dbase=false) then
                  begin
                    if (repair=true) and ((cmp=false) or (garbage=true)) then
                      begin
                        WriteNesHdr(name,resulthdr,errcode);
                        if errcode=0 then
                          begin
                            rpcount:=rpcount+1;
                            if copy(name,length(name)-3,1)='.' then rtmp:=copy(name,1,length(name)-4);
                            if nobackup=true then
                              LFNErase(rtmp+'.ba~',FA_NORMAL,FA_NORMAL,false) else
                              LFNMove(rtmp+'.ba~',dir_backup+rtmp+'.bak','','',errcode);
                          end;
                        if errcode>0 then notrepaired:=true;
                      end;
                    if (rname=true) and (dupe=false) then
                      if result+'.nes'<>name then
                        begin
                          if sort=true then
                            begin
                              sorted:=true;
                              sortdir:=getsortdir(sortcode);
                              if (sorttrans=true) and (nes.country=512) then sortdir:=sortdir+transdir(result)+'\';
                              if sortmapper=true then sortdir:=sortdir+i2s(resulthdr.mapper,3)+'\';
                              if notrepaired=true then sortdir:=dir_repair;
                            end else sortdir:='.\';
                          LFNMove(name,sortdir+result+'.nes',csum,countryi2s(nes.country),errcode);
                          if errcode=0 then rncount:=rncount+1 else
                            begin
                              notrenamed:=true;
                              if errcode<>100 then nomove:=nomove+1;
                            end;
                        end;
                    if (extout=true) and ((cmp=false) or (namematch=false) or (garbage=true)) then
                      begin
                        if quiet=true then
                          begin
                            gotoxy(1,wy);
                            writeln(out);
                            if out2<>'' then writeln(out2);
                          end;
                        if (outfile=true) and (outquiet=true) then
                          begin
                            writeln(ofile,out);
                            if out2<>'' then writeln(ofile,out2);
                          end;
                        out:=formatoutput(result,resulthdr,false,'',0,l,view_bl);
                        checksplit(out,out2);
                        outm:='   Bad [----]';
                        if (rname=true) and (namematch=false) then outm:='   Ren [----]';
                        if (repair=true) and (cmp=false) then outm:='   Rep [----]';
                        if namematch=false then outm[9]:='N';
                        if cmp=false then outm[10]:='H';
                        if nes.other<>null8 then outm[11]:='G';
                        if (nes.vs=1) and (nes.pc10=1) then outm[11]:='G';
                        if garbage=true then outm[12]:='T';
                        if notrenamed=true then outm:=' Can''t Rename';
                        if notrepaired=true then outm:=' Can''t Repair';
                        out:=out+outm;
                        writeln(out);
                        if out2<>'' then writeln(out2);
                        writeln;
                        if (quiet=true) and (wy<24) then wy:=wherey-1;
                        if outfile=true then
                          begin
                            writeln(ofile,out);
                            if out2<>'' then writeln(ofile,out2);
                            if quiet=false then writeln(ofile);
                          end;
                      end;
                  end;
                if (sort=true) and (dupe=false) and (sorted=false) then
                  begin
                    sortdir:=getsortdir(sortcode);
                    if (sorttrans=true) and (dbpos>0) and (nes.country=512)
                      then sortdir:=sortdir+transdir(result)+'\';
                    if sortmapper=true then
                      begin
                        if dbpos>0 then sortdir:=sortdir+i2s(resulthdr.mapper,3)+'\'
                                   else sortdir:=sortdir+i2s(nes.mapper,3)+'\';
                      end;
                    if notrepaired=true then sortdir:=dir_repair;
                    LFNMove(name,sortdir,csum,countryi2s(nes.country),errcode);
                    if (errcode>0) and (errcode<>100) then nomove:=nomove+1;
                  end;
                if dupe=true then
                  if (rname=true) and (result+'.nes'<>name) then
                    begin
                      LFNMove(name,dir_dupes+result+'.nes','','',errcode);
                      if errcode=0 then rncount:=rncount+1;
                    end else LFNMove(name,dir_dupes,'','',errcode);
                if (dbpos>0) and (flagrom=true) and (prgfound=false)
                  then csumdbase[dbpos].flag:=true;
                if (dir_savestates<>'') and (rname=true) and (notrenamed=false) then
                  if result+'.nes'<>name then renamesaves(result,name);
              end;
          end;
        LFNChDir(cpath);
      end;
      readdirclose(f);
    end;
  patharrayclear(numpaths);
  gettime(hour,min,sec,hund);
  fullendtime:=sec+min*60+hour*3600;
  if fullendtime<fullstarttime then fullendtime:=fullendtime+82800;
  difftime:=fullendtime-fullstarttime;
  hour:=difftime div 3600;
  difftime:=difftime mod 3600;
  min:=difftime div 60;
  sec:=difftime mod 60;
  if romcount=0 then writeln('No ROMs found') else begin writeln; writeln(romcount,sstr(' ROM',romcount),' found'); end;
  if matchcount>0 then writeln(matchcount,sstr(' ROM',matchcount),' found in database');
  if prgcount>0 then writeln(prgcount,sstr(' ROM',prgcount),' found with bad CHR banks');
  if rpcount>0 then writeln(rpcount,sstr(' ROM',rpcount),' repaired');
  if rncount>0 then writeln(rncount,sstr(' ROM',rncount),' renamed');
  if rscount>0 then writeln(rscount,sstr(' ROM',rscount),' resized');
  if nomove>0 then writeln('Unable to sort ',nomove,sstr(' ROM',nomove));
  writeln;
  write('Finished in ');
  if hour>0 then write(hour,sstr(' hour',hour),', ');
  if min>0 then write(min,sstr(' minute',min),' and ');
  writeln(sec,sstr(' second',sec),'.');
  if (outfile=true) and (dbase=false) then
    begin
      if romcount=0 then writeln(ofile,'No ROMs found')
      else begin writeln(ofile); writeln(ofile,romcount,sstr(' ROM',romcount),' found'); end;
      if matchcount>0 then writeln(ofile,matchcount,sstr(' ROM',matchcount),' found in database');
      if prgcount>0 then writeln(ofile,prgcount,sstr(' ROM',prgcount),' found with bad CHR banks');
      if rpcount>0 then writeln(ofile,rpcount,sstr(' ROM',rpcount),' repaired');
      if rncount>0 then writeln(ofile,rncount,sstr(' ROM',rncount),' renamed');
      if rscount>0 then writeln(ofile,rscount,sstr(' ROM',rscount),' resized');
      if nomove>0 then writeln(ofile,'Unable to sort ',nomove,sstr(' ROM',nomove));
      writeln(ofile);
      write(ofile,'Finished in ');
      if hour>0 then write(ofile,hour,sstr(' hour',hour),', ');
      if min>0 then write(ofile,min,sstr(' minute',min),' and ');
      writeln(ofile,sec,sstr(' second',sec),'.');
    end;
  if outfile=true then close(ofile);
  if logging=true then close(lfile);
  if dbasemissing=true then listmissing(allmissing,missingsort);
  dbaseclose;
end.
