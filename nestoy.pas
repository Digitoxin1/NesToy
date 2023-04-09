program NesToy;
{$X+}
{$M 40960,0,655360}

uses
  dos,dos70,crc32new,crt,strings,runtime,
  utility,cmdline,genemu,lfnutil;

type
  country=string[10];
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
           country:country;    {Country Code (Not in header)}
           company:string[25]; {Company (Not in header)}
         end;

const
  dirlimit=6;
  maxdbasesize=3200;
  maxdirsize=3500;
  maxpathnames=100;
  empty='0000000000';
  null8=#0+#0+#0+#0+#0+#0+#0+#0;
  hdrstring='NES'+#26;
  dbasefile='NESDBASE.DAT';
  cfgfile='NESTOY.CFG';
  outputfile='OUTPUT.TXT';
  logfile='NESTOY.LOG';
  version='4.1';
  missingfile:string='NESMISS.TXT';
  param_ren:string[10]='';
  param_missing:string[10]='';
  dir_base:string='';
  dir_asia:string='Asia\';
  dir_backup:string='Backup\';
  dir_bad:string='Bad\';
  dir_dupes:string='Dupes\';
  dir_europe:string='Europe\';
  dir_gamehacks:string='Game Hacks\';
  dir_hacked:string='Hacked\';
  dir_japan:string='Japan\';
  dir_maphacks:string='Mapper Hacks\';
  dir_other:string='Other\';
  dir_pc10:string='Playchoice 10\';
  dir_pd:string='PD\';
  dir_pirate:string='Pirate\';
  dir_repair:string='Repair\';
  dir_trans:string='Translated\';
  dir_unknown:string='Unknown\';
  dir_northamerica:string='North America\';
  dir_vs:string='VS Unisystem\';
  dir_savestates:string='';
  dir_patches:string='';
  move_bad:boolean=true;
  move_hacked:boolean=true;
  move_pirate:boolean=true;
  sort_trans:boolean=true;
  sort_unlicensed:boolean=true;
  missing_bad:boolean=false;
  missing_gamehacks:boolean=false;
  missing_hacked:boolean=true;
  missing_pirate:boolean=true;
  missing_trans:boolean=false;
  joliet:boolean=false;
  shortname:boolean=false;
  tagunl:boolean=false;
  win2000:boolean=false;
  badchr:string=' (Bad CHR';

var
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

procedure loaddirs(inpath,clfname:string;limit:integer);
var
  f,f2:word;
  dirinfo,dirinfo2:tfinddata;
  arraytemp:charstr;
begin
  f:=lfnfindfirst(inpath+'*.*',FA_DIR,FA_DIR,dirinfo);
  while (dos7error=0) and (numpaths<maxpathnames-1) do
    begin
      if (dirinfo.name<>'.') and (dirinfo.name<>'..') and (limit>0) then
        if (upcasestr(inpath+dirinfo.name+'\')<>upcasestr(dir_dupes)) and
           (upcasestr(inpath+dirinfo.name+'\')<>upcasestr(dir_backup)) then
          begin
            f2:=lfnfindfirst(inpath+dirinfo.name+'\'+clfname,FA_NORMAL,FA_NORMAL,dirinfo2);
            if dos7error=0 then
              begin
                numpaths:=numpaths+1;
                str2chr(clfname,arraytemp);
                clf[numpaths]:=strnew(arraytemp);
                str2chr(inpath+dirinfo.name+'\',arraytemp);
                path[numpaths]:=strnew(arraytemp);
              end;
            lfnfindclose(f2);
            loaddirs(inpath+dirinfo.name+'\',clfname,limit-1);
          end;
      lfnfindnext(f,dirinfo);
    end;
  lfnfindclose(f);
end;

procedure patharrayclear(count:word);
var
  counter:integer;
begin
  for counter:=count downto 1 do
    begin
      strdispose(path[counter]);
      strdispose(clf[counter]);
    end;
end;

function countrys2i(s:string):country;
var
  c:string[10];
begin
  c:=empty;
  if pos('J',s)>0 then c[1]:='1';  {Japan}
  if pos('U',s)>0 then c[2]:='1';  {USA}
  if pos('C',s)>0 then c[2]:='2';  {Canada}
  if pos('E',s)>0 then c[3]:='1';  {Europe}
  if pos('F',s)>0 then c[3]:='2';  {France}
  if pos('Ge',s)>0 then c[3]:='3'; {Germany}
  if pos('Sp',s)>0 then c[3]:='4'; {Spain}
  if pos('Sw',s)>0 then c[3]:='5'; {Sweden}
  if pos('I',s)>0 then c[3]:='6';  {Italy}
  if pos('Au',s)>0 then c[3]:='7'; {Australia}
  if pos('As',s)>0 then c[4]:='1'; {Asia}
  if pos('V',s)>0 then c[5]:='1';  {Vs. Unisystem}
  if pos('P',s)>0 then c[5]:='2';  {Playchoice-10}
  if pos('PD',s)>0 then c[5]:='3'; {Public Domain}
  if pos('T',s)>0 then c[6]:='1';  {Translations}
  if pos('Z',s)>0 then c[7]:='1';  {Pirates}
  if pos('H',s)>0 then c[8]:='1';  {Hacked}
  if pos('M',s)>0 then c[8]:='2';  {Mapper Hacks}
  if pos('GH',s)>0 then c[8]:='3'; {Game Hacks}
  if pos('O',s)>0 then c[8]:='4';  {Other}
  if pos('B',s)>0 then c[9]:='1';  {Bad Dumps}
  if pos('X',s)>0 then c[10]:='1'; {Unlicensed}
  countrys2i:=c;
end;

function countryi2s(c:country):string;
var
  temp:string;
begin
  temp:='';
  temp:=' (';
  if c[1]='1' then temp:=temp+'J';
  if c[2]='1' then temp:=temp+'U';
  if c[3]='1' then temp:=temp+'E';
  temp:=temp+')';
  if c[2]='2' then temp:=' (Canada)';
  if c[3]='2' then temp:=' (France)';
  if c[3]='3' then temp:=' (Germany)';
  if c[3]='4' then temp:=' (Spain)';
  if c[3]='5' then temp:=' (Sweden)';
  if c[3]='6' then temp:=' (Italy)';
  if c[3]='7' then temp:=' (Australia)';
  if c[4]='1' then temp:=' (Asia)';
  if c[5]='1' then temp:=' (VS)';
  if c[5]='2' then temp:=' (PC10)';
  if c[5]='3' then temp:=' (PD)';
  if temp=' ()' then temp:='';
  countryi2s:=temp;
end;

function checkhidden(str:string):byte;
var
  tbyte:byte;
begin
  tbyte:=0;
  if str='SMGH' then tbyte:=1;
  if str='SMTR' then tbyte:=2;
  checkhidden:=tbyte;
end;

function transdir(str:string):string;
var
  tempstr:string;
begin
  tempstr:='';
  str:=upcasestr(str);
  if pos('(BRAZIL',str)>0 then tempstr:='Portuguese';
  if pos('(ENGLISH',str)>0 then tempstr:='English';
  if pos('(FRENCH',str)>0 then tempstr:='French';
  if pos('(GERMAN',str)>0 then tempstr:='German';
  if pos('(ITALIAN',str)>0 then tempstr:='Italian';
  if pos('(POLISH',str)>0 then tempstr:='Polish';
  if pos('(PORTUGUESE',str)>0 then tempstr:='Portuguese';
  if pos('(RUSSIAN',str)>0 then tempstr:='Russian';
  if pos('(SPANISH',str)>0 then tempstr:='Spanish';
  if pos('(SWEDISH',str)>0 then tempstr:='Swedish';
  if tempstr='' then tempstr:='Unknown';
  transdir:=tempstr;
end;

function getsortdir(code:string):string;
var
  tempdir:string;
begin
  tempdir:='';
  if code=empty then tempdir:=dir_unknown;
  if code[8]='4' then tempdir:=dir_other;
  if code[7]='1' then tempdir:=dir_pirate;
  if code[8]='2' then tempdir:=dir_maphacks;
  if code[8]='3' then tempdir:=dir_gamehacks;
  if code[8]='1' then tempdir:=dir_hacked;
  if code[9]='1' then tempdir:=dir_bad;
  if code[3]>'0' then tempdir:=dir_europe;
  if code[1]>'0' then tempdir:=dir_japan;
  if code[2]>'0' then tempdir:=dir_northamerica;
  if code[4]>'0' then tempdir:=dir_asia;
  if code[5]='1' then tempdir:=dir_vs;
  if code[5]='2' then tempdir:=dir_pc10;
  if code[5]='3' then tempdir:=dir_pd;
  if code[6]='1' then tempdir:=dir_trans;
  if code='PIRATE' then tempdir:=dir_pirate;
  if code='MAPHACKS' then tempdir:=dir_maphacks;
  if code='GAMEHACKS' then tempdir:=dir_gamehacks;
  if code='HACKED' then tempdir:=dir_hacked;
  if code='BAD' then tempdir:=dir_bad;
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
                   destpath:=destpath+Int2Str(ctr,0);
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

procedure renamepats(result,name:string);
var
  f:word;
  dirinfo:tfinddata;
  tempstr,tempres:string;
begin
  if copy(name,length(name)-3,1)='.' then
    name:=copy(name,1,length(name)-4);
  f:=LFNFindFirst(dir_patches+name+'.*',FA_NORMAL,FA_NORMAL,dirinfo);
  while dos7error=0 do
    begin
      tempstr:=dirinfo.name;
      tempstr:=copy(tempstr,length(tempstr)-3,4);
      if upcasestr(tempstr)='.PAT' then
        begin
          tempres:=result+tempstr;
          lfnrename(dir_patches+dirinfo.name,dir_patches+tempres);
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
  nh.country:=empty;
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
      dbpos:=Str2Int(copy(dbstr,9,length(dbstr)-8));
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
  dir_asia:=expandwork(dir_asia,true);
  dir_base:=expandwork(dir_base,false);
  dir_backup:=expandwork(dir_backup,true);
  dir_bad:=expandwork(dir_bad,true);
  dir_dupes:=expandwork(dir_dupes,true);
  dir_europe:=expandwork(dir_europe,true);
  dir_gamehacks:=expandwork(dir_gamehacks,true);
  dir_hacked:=expandwork(dir_hacked,true);
  dir_japan:=expandwork(dir_japan,true);
  dir_maphacks:=expandwork(dir_maphacks,true);
  dir_northamerica:=expandwork(dir_northamerica,true);
  dir_other:=expandwork(dir_other,true);
  dir_pc10:=expandwork(dir_pc10,true);
  dir_pd:=expandwork(dir_pd,true);
  dir_pirate:=expandwork(dir_pirate,true);
  dir_repair:=expandwork(dir_repair,true);
  dir_trans:=expandwork(dir_trans,true);
  dir_unknown:=expandwork(dir_unknown,true);
  dir_vs:=expandwork(dir_vs,true);
  if dir_savestates<>'' then dir_savestates:=expandwork(dir_savestates,true);
  if dir_patches<>'' then dir_patches:=expandwork(dir_patches,true);
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
      writeln(f,'DIR_ASIA = ',dir_asia);
      writeln(f,'DIR_BACKUP = ',dir_backup);
      writeln(f,'DIR_BAD = ',dir_bad);
      writeln(f,'DIR_DUPLICATES = ',dir_dupes);
      writeln(f,'DIR_EUROPE = ',dir_europe);
      writeln(f,'DIR_GAMEHACKS = ',dir_gamehacks);
      writeln(f,'DIR_HACKED = ',dir_hacked);
      writeln(f,'DIR_JAPAN = ',dir_japan);
      writeln(f,'DIR_MAPHACKS = ',dir_maphacks);
      writeln(f,'DIR_NORTHAMERICA = ',dir_northamerica);
      writeln(f,'DIR_OTHER = ',dir_other);
      writeln(f,'DIR_PC10 = ',dir_pc10);
      writeln(f,'DIR_PD = ',dir_pd);
      writeln(f,'DIR_PIRATE = ',dir_pirate);
      writeln(f,'DIR_TRANS = ',dir_trans);
      writeln(f,'DIR_UNKNOWN = ',dir_unknown);
      writeln(f,'DIR_VS = ',dir_vs);
      writeln(f,'DIR_SAVESTATES = ',dir_savestates);
      writeln(f,'DIR_PATCHES = ',dir_patches);
      writeln(f);
      writeln(f,'MOVE_BAD = ',move_bad);
      writeln(f,'MOVE_HACKED = ',move_hacked);
      writeln(f,'MOVE_PIRATE = ',move_pirate);
      writeln(f,'SORT_TRANS = ',sort_trans);
      writeln(f,'SORT_UNLICENSED = ',sort_unlicensed);
      writeln(f);
      writeln(f,'MISSING_BAD = ',missing_bad);
      writeln(f,'MISSING_HACKED = ',missing_hacked);
      writeln(f,'MISSING_PIRATE = ',missing_pirate);
      writeln(f);
      writeln(f,'FILE_MISSING = ',missingfile);
      writeln(f,'SHORT_NAMES = ',shortname);
      writeln(f,'JOLIET = ',joliet);
      writeln(f,'TAG_UNLICENSED = ',tagunl);
      writeln(f,'WIN2000 = ',win2000);
      writeln(f);
      writeln(f,'PARAM_MISSING = ',param_missing);
      writeln(f,'PARAM_REN = ',param_ren);
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
              if s='DIR_ASIA' then dir_asia:=s2;
              if s='DIR_BACKUP' then dir_backup:=s2;
              if s='DIR_BAD' then dir_bad:=s2;
              if s='DIR_DUPLICATES' then dir_dupes:=s2;
              if s='DIR_EUROPE' then dir_europe:=s2;
              if s='DIR_GAMEHACKS' then dir_gamehacks:=s2;
              if s='DIR_JAPAN' then dir_japan:=s2;
              if s='DIR_MAPHACKS' then dir_maphacks:=s2;
              if s='DIR_NORTHAMERICA' then dir_northamerica:=s2;
              if s='DIR_OTHER' then dir_other:=s2;
              if s='DIR_PC10' then dir_pc10:=s2;
              if s='DIR_PD' then dir_pd:=s2;
              if s='DIR_PIRATE' then dir_pirate:=s2;
              if s='DIR_HACKED' then dir_hacked:=s2;
              if s='DIR_TRANS' then dir_trans:=s2;
              if s='DIR_UNKNOWN' then dir_unknown:=s2;
              if s='DIR_VS' then dir_vs:=s2;
              if s='DIR_SAVESTATES' then dir_savestates:=s2;
              if s='DIR_PATCHES' then dir_patches:=s2;
              if s='FILE_MISSING' then missingfile:=s2;
              if s='PARAM_MISSING' then param_missing:=upcasestr(s2);
              if s='PARAM_REN' then param_ren:=upcasestr(s2);
              if s='TAG_UNLICENSED' then if upcasestr(s2)='FALSE' then tagunl:=false else
                if upcasestr(s2)='TRUE' then tagunl:=true;
              if s='SHORT_NAMES' then if upcasestr(s2)='FALSE' then shortname:=false else
                if upcasestr(s2)='TRUE' then shortname:=true;
              if s='JOLIET' then if upcasestr(s2)='FALSE' then joliet:=false else
                if upcasestr(s2)='TRUE' then joliet:=true;
              if s='WIN2000' then if upcasestr(s2)='FALSE' then win2000:=false else
                if upcasestr(s2)='TRUE' then win2000:=true;
              if s='MOVE_BAD' then if upcasestr(s2)='FALSE' then move_bad:=false else
                if upcasestr(s2)='TRUE' then move_bad:=true;
              if s='MOVE_HACKED' then if upcasestr(s2)='FALSE' then move_hacked:=false else
                if upcasestr(s2)='TRUE' then move_hacked:=true;
              if s='MOVE_PIRATE' then if upcasestr(s2)='FALSE' then move_pirate:=false else
                if upcasestr(s2)='TRUE' then move_pirate:=true;
              if s='SORT_TRANS' then if upcasestr(s2)='FALSE' then sort_trans:=false else
                if upcasestr(s2)='TRUE' then sort_trans:=true;
              if s='SORT_UNLICENSED' then if upcasestr(s2)='FALSE' then sort_unlicensed:=false else
                if upcasestr(s2)='TRUE' then sort_unlicensed:=true;
              if s='MISSING_BAD' then if upcasestr(s2)='FALSE' then missing_bad:=false else
                if upcasestr(s2)='TRUE' then missing_bad:=true;
              if s='MISSING_HACKED' then if upcasestr(s2)='FALSE' then missing_hacked:=false else
                if upcasestr(s2)='TRUE' then missing_hacked:=true;
              if s='MISSING_PIRATE' then if upcasestr(s2)='FALSE' then missing_pirate:=false else
                if upcasestr(s2)='TRUE' then missing_pirate:=true;
              if checkhidden(s)=1 then if upcasestr(s2)='FALSE' then missing_gamehacks:=false else
                if upcasestr(s2)='TRUE' then missing_gamehacks:=true;
              if checkhidden(s)=2 then if upcasestr(s2)='FALSE' then missing_trans:=false else
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
      strpcopy(csprg,copy(s,10,8)+Int2Str(dbasecount,0));
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
  otemp:string[5];
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
      otemp:='     ';
      if copy(minfo.country,1,5)='00000' then otemp:=' ??? ';
      if minfo.country[1]='1' then otemp[2]:='J';
      if minfo.country[2]='1' then otemp[3]:='U';
      if minfo.country[3]='1' then otemp[4]:='E';
      if minfo.country[10]='1' then otemp[5]:='@';
      if minfo.country[2]='2' then otemp:=' Can ';
      if minfo.country[3]='2' then otemp:=' Fra ';
      if minfo.country[3]='3' then otemp:=' Ger ';
      if minfo.country[3]='4' then otemp:=' Spa ';
      if minfo.country[3]='5' then otemp:=' Swe ';
      if minfo.country[3]='6' then otemp:=' Ita ';
      if minfo.country[3]='7' then otemp:=' Aus ';
      if minfo.country[4]='1' then otemp:=' Asi ';
      if minfo.country[5]='1' then otemp:=' VS  ';
      if minfo.country[5]='2' then otemp:=' P10 ';
      if minfo.country[5]='3' then otemp:=' PD  ';
      if minfo.country[6]='1' then otemp:=' TR  ';
      if minfo.country[8]='3' then otemp:=' GH  ';
      out:=out+otemp;
    end;
  if docsum=true then out:=out+csum;
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
          p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
          val(ts2,x,code); dbaseinfo.chr:=x;
          p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
          dbaseinfo.country:=countrys2i(ts2);
          p:=pos(';',ts); if p=0 then ts2:=ts else begin ts2:=copy(ts,1,p-1); delete(ts,1,p); end;
          dbaseinfo.company:=ts2;
          skipflag:=false;
          if (dbaseinfo.country[6]='1') and (missing_trans=false) then skipflag:=true;
          if (dbaseinfo.country[7]='1') and (missing_pirate=false) then skipflag:=true;
          if (dbaseinfo.country[8]='1') and (missing_hacked=false) then skipflag:=true;
          if (dbaseinfo.country[8]='2') and (missing_gamehacks=false) then skipflag:=true;
          if (dbaseinfo.country[8]='3') and (missing_hacked=false) then skipflag:=true;
          if (dbaseinfo.country[9]='1') and (missing_bad=false) then skipflag:=true;
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
      writeln(f2,acount,' missing',AddS(' ROM',acount),' out of ',dbasecount-badcount);
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
    writeln('-sort[m]       Sorts ROMs into directories by region or type');
    writeln('                  m- Sorts ROMs by mapper # as well');
    writeln('-m#            Filter listing by mapper #');
    writeln('-f[hvbt4]      Filter listing by mapper data');
    pause;
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
  f:word;
  h,ns,csum,prgcsum:string;
  clfname,pathname,sortdir:string;
  arraytemp:charstr;
  l,ctr,csumpos,err,lr:integer;
  msearch,rflag,counter:integer;
  matchcount,nomove,prgcount,rncount,romcount,rpcount,rscount:integer; {ROM Counters}
  dirromcount:integer;
  dbpos,io,pc,wy:integer;
  fcpos:integer;
 {Command Line Parameters ---------------------------------------------------------------------}
  docsum,extout,nobackup,outfile,resize,repair,subdir,unknown,view_bl:boolean;
  dbasemissing,allmissing,missingsort:boolean; {Missing Options}
  sort,sortmapper:boolean; {Sorting}
  show_4,show_b,show_h,show_t,show_v:boolean; {Filters}
  rname,ccode,lowcasename,mthe,remperiod,remspace,uscore:boolean; {Renaming}
  dbase,extdbase:boolean; {Database Output}
 {---------------------------------------------------------------------------------------------}
  namematch,cmp,abort:boolean;
  booltemp,shorten:boolean;
  result,rtmp,rtmp2,ralt:string;
  key:char;
  outm:string[13];
  ofile:text;
  errcode:word;
  name:string;
  newprg,newchr:byte;
  sortcode:string[10];
  filedt:NewDateTime;
  hour,min,sec,hund:word;
  Year,Month,Day,DOW:word;
  fullstarttime,fullendtime,difftime,temptime:longint;
  fs:integer;

procedure initialize;
begin
  checkbreak:=false;
  cfgparam:='';
  progpath:=paramstr(0);
  while copy(progpath,length(progpath),1)<>'\' do
    delete(progpath,length(progpath),1);
  loadcfgfile;
  if (IsDOS70=false) and (win2000=false) then usage(2);
  loaddbase;
  initextparamstr(cfgparam);
  cpath:=getfullpathname('.\',false);
  pathname:='';
 {Command Line Parameters ---------------------------------------------------------------------}
  docsum:=false; extout:=false; nobackup:=false; outfile:=false; resize:=false;
  repair:=false; subdir:=false; unknown:=false; view_bl:=false;
  dbasemissing:=false; allmissing:=true; missingsort:=false; overwritemissing:=false;
  sort:=false; sortmapper:=false;
  show_4:=false; show_b:=false; show_h:=false; show_t:=false; show_v:=false;
  rname:=false; ccode:=false; lowcasename:=false; mthe:=false; remperiod:=true; remspace:=false; uscore:=false;
  dbase:=false; extdbase:=false;
  logging:=false; quiet:=false; outquiet:=false;
 {---------------------------------------------------------------------------------------------}
  matchcount:=0; nomove:=0; prgcount:=0; rncount:=0; romcount:=0; rpcount:=0; rscount:=0;
  numpaths:=0;
  abort:=false;
  msearch:=-1;
end;

procedure parsecommandline;
var
  sps:integer;
begin
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
          if subdir=true then loaddirs(pathname,clfname,dirlimit);
          numpaths:=numpaths+1;
          str2chr(clfname,arraytemp);
          clf[numpaths]:=strnew(arraytemp);
          str2chr(pathname,arraytemp);
          path[numpaths]:=strnew(arraytemp);
        end;
    end;
  searchps('-c',sps,result);
  if sps>0 then docsum:=true;
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
      result:=result+param_ren;
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
      result:=result+param_missing;
      if pos('C',result)>0 then missingsort:=true;
      if pos('B',result)>0 then allmissing:=false;
      if pos('N',result)>0 then overwritemissing:=true;
    end;
  searchps('-sort*',sps,result);
  if sps>0 then
    begin
      sort:=true; docsum:=true;
      if pos('M',result)>0 then sortmapper:=true;
    end;
  searchps('-doall',sps,result);
  if sps>0 then begin
                  docsum:=true; rname:=true; repair:=true; resize:=true; extout:=true;
                  dbasemissing:=true; sort:=true;
                  if pos('U',param_ren)>0 then uscore:=true;
                  if pos('S',param_ren)>0 then remspace:=true;
                  if pos('C',param_ren)>0 then ccode:=true;
                  if pos('L',param_ren)>0 then lowcasename:=true;
                  if pos('T',param_ren)>0 then mthe:=true;
                  if pos('P',param_ren)>0 then remperiod:=false;
                  if pos('C',param_missing)>0 then missingsort:=true;
                  if pos('B',param_missing)>0 then allmissing:=false;
                  if pos('N',param_missing)>0 then overwritemissing:=true;
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
end;

procedure main;
var
  badrom,dupe,ghackedrom,hackedrom,mhackedrom,piraterom:boolean;
  cropped,notrenamed,notrepaired,sorted:boolean;
  garbage,prgfound,show,unlflag:boolean;
  out,out2:string;
  nes,oldnes,resulthdr:NesHdr;
  byte7,byte8:byte;
  attrib:word;
begin
  out:=''; out2:='';
  flagrom:=true;
  show:=true;
  garbage:=false;
  notrenamed:=false; notrepaired:=false;
  cropped:=false; sorted:=false;
  badrom:=false; dupe:=false; ghackedrom:=false;
  hackedrom:=false; mhackedrom:=false; piraterom:=false;
  prgfound:=false; unlflag:=false;
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
                  if (FileDT.year=year) and (FileDT.month=month) and (FileDT.day=day) then
                     if temptime<fullstarttime-5 then dupe:=true;
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
          shorten:=shortname;
          lr:=length(result);
          if pos('<',result)>0 then lr:=lr-2;
          if (joliet=true) and (lr>60) then shorten:=true;
          result:=shortparse(result,shorten);
          if pos('(UNL',upcasestr(result))=0 then unlflag:=true;
          if (unlflag=true) and (tagunl=true) and (resulthdr.country[10]='1') then
            result:=result+' (Unl)';
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
          if nes.country[7]='1' then piraterom:=true;
          if nes.country[8]='2' then mhackedrom:=true;
          if nes.country[8]='3' then ghackedrom:=true;
          if nes.country[8]='1' then hackedrom:=true;
          if nes.country[9]='1' then badrom:=true;
          if mthe=true then result:=movethe(result);
          if (ccode=true) or (nes.country[2]>'1') or (nes.country[3]>'1') then
            result:=result+countryi2s(nes.country);
          if lowcasename=true then result:=lowcasestr(result);
          if remspace=true then result:=SpaceCvt(result,false);
          if uscore=true then result:=SpaceCvt(result,true);
          if remperiod=true then
            begin
              ralt:=result;
              result:=PeriodCvt(result);
            end else ralt:=PeriodCvt(result);
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
                if (SpaceCvt(rtmp,true)=name) or (SpaceCvt(rtmp2,true)=name) then namematch:=true else
                  if (SpaceCvt(rtmp,false)=name) or (SpaceCvt(rtmp2,false)=name) then namematch:=true else
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
                      if (SpaceCvt(rtmp,true)=name) or (SpaceCvt(rtmp2,true)=name) then namematch:=true else
                      if (SpaceCvt(rtmp,false)=name) or (SpaceCvt(rtmp2,false)=name) then namematch:=true
                    end;
            end;
          if result[length(result)]='.' then delete(result,length(result),1);
          if badrom=true then rflag:=6;
          if namematch=false then rflag:=4;
          if (cmp=false) or (garbage=true) then rflag:=3;
          if dupe=true then rflag:=5;
        end;
      if dbase=false then
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
        end else
        begin
          if extdbase=false then
            begin
              out:=out+csum+';'+prgcsum+';'+name;
              if copy(out,length(out)-3,1)='.' then out:=copy(out,1,length(out)-4);
              byte7:=nes.mirror+nes.sram*2+nes.trainer*4+nes.fourscr*8+nes.mapper mod 16*16;
              byte8:=nes.vs+nes.pc10*2+nes.mapper div 16*16;
              out:=out+';'+Int2Str(byte7,0);
              out:=out+';'+Int2Str(byte8,0);
              out:=out+';'+Int2Str(nes.prg,0);
              out:=out+';'+Int2Str(nes.chr,0);
            end else
            begin
              out:=out+'"'+csum+'","'+name;
              if copy(out,length(out)-3,1)='.' then out:=copy(out,1,length(out)-4);
              out:=out+'"';
              out:=out+','+Int2Str(nes.mapper,0)+',';
              out:=out+Int2Str(nes.mirror,0)+','+Int2Str(nes.sram,0)+',';
              out:=out+Int2Str(nes.trainer,0)+','+Int2Str(nes.fourscr,0)+',"';
              if nes.mirror=1 then out:=out+'V' else out:=out+'H';
              if nes.sram=1 then out:=out+'B' else out:=out+'.';
              if nes.trainer=1 then out:=out+'T' else out:=out+'.';
              if nes.fourscr=1 then out:=out+'4' else out:=out+'.';
              out:=out+'",'+Int2Str(nes.prg,0)+','+Int2Str(nes.chr,0);
            end;
        end;
      sortcode:=nes.country;
      if (piraterom=true) and (move_pirate=true) then sortcode:='PIRATE';
      if (mhackedrom=true) and (move_hacked=true) then sortcode:='MAPHACKS';
      if ghackedrom=true then sortcode:='GAMEHACKS';
      if (hackedrom=true) and (move_hacked=true) then sortcode:='HACKED';
      if (badrom=true) and (move_bad=true) then sortcode:='BAD';
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
                  if (sort_trans=true) and (nes.country[6]='1') then sortdir:=sortdir+transdir(result)+'\';
                  if (sort_unlicensed=true) and (copy(nes.country,5,6)='000001')
                    then sortdir:=sortdir+'Unlicensed\';
                  if sortmapper=true then sortdir:=sortdir+Int2Str(resulthdr.mapper,3)+'\';
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
          if (sort_trans=true) and (dbpos>0) and (nes.country[6]='1') then
            sortdir:=sortdir+transdir(result)+'\';
          if (sort_unlicensed=true) and (dbpos>0) and (copy(nes.country,5,6)='000001') then
            sortdir:=sortdir+'Unlicensed\';
          if sortmapper=true then
            begin
              if dbpos>0 then sortdir:=sortdir+Int2Str(resulthdr.mapper,3)+'\'
                         else sortdir:=sortdir+Int2Str(nes.mapper,3)+'\';
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
      if (dbpos>0) and (flagrom=true) and (prgfound=false) then
        csumdbase[dbpos].flag:=true;
      if (rname=true) and (notrenamed=false) then
        begin
          if dir_savestates<>'' then if result+'.nes'<>name then renamesaves(result,name);
          if dir_patches<>''then if result+'.nes'<>name then renamepats(result,name);
        end;
    end;
end;

begin
  initialize;
  parsecommandline;
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
                  if keypressed=true then
                    begin
                      key:=readkey;
                      if key=#27 then abort:=true;
                    end;
                  main;
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
  if romcount=0 then writeln('No ROMs found') else begin writeln; writeln(romcount,AddS(' ROM',romcount),' found'); end;
  if matchcount>0 then writeln(matchcount,AddS(' ROM',matchcount),' found in database');
  if prgcount>0 then writeln(prgcount,AddS(' ROM',prgcount),' found with bad CHR banks');
  if rpcount>0 then writeln(rpcount,AddS(' ROM',rpcount),' repaired');
  if rncount>0 then writeln(rncount,AddS(' ROM',rncount),' renamed');
  if rscount>0 then writeln(rscount,AddS(' ROM',rscount),' resized');
  if nomove>0 then writeln('Unable to sort ',nomove,AddS(' ROM',nomove));
  writeln;
  write('Finished in ');
  if hour>0 then write(hour,AddS(' hour',hour),', ');
  if min>0 then write(min,AddS(' minute',min),' and ');
  writeln(sec,AddS(' second',sec),'.');
  if (outfile=true) and (dbase=false) then
    begin
      if romcount=0 then writeln(ofile,'No ROMs found')
      else begin writeln(ofile); writeln(ofile,romcount,AddS(' ROM',romcount),' found'); end;
      if matchcount>0 then writeln(ofile,matchcount,AddS(' ROM',matchcount),' found in database');
      if prgcount>0 then writeln(ofile,prgcount,AddS(' ROM',prgcount),' found with bad CHR banks');
      if rpcount>0 then writeln(ofile,rpcount,AddS(' ROM',rpcount),' repaired');
      if rncount>0 then writeln(ofile,rncount,AddS(' ROM',rncount),' renamed');
      if rscount>0 then writeln(ofile,rscount,AddS(' ROM',rscount),' resized');
      if nomove>0 then writeln(ofile,'Unable to sort ',nomove,AddS(' ROM',nomove));
      writeln(ofile);
      write(ofile,'Finished in ');
      if hour>0 then write(ofile,hour,AddS(' hour',hour),', ');
      if min>0 then write(ofile,min,AddS(' minute',min),' and ');
      writeln(ofile,sec,AddS(' second',sec),'.');
    end;
  if outfile=true then close(ofile);
  if logging=true then close(lfile);
  if dbasemissing=true then listmissing(allmissing,missingsort);
  dbaseclose;
end.
