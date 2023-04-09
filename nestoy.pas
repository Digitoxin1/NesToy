program NesToy;
{$X+}
{$M 40960,0,655360}
uses
  dos,dos70,crc32c,crt,strings;

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
           country:byte;       {Country Code (Not in header)}
           company:string[25]; {Company (Not in header)}
         end;
  updown   = (ascending,descending);
  dataType = array[0..255] of char;     { the Type of data to be sorted }
  dataptr  = ^dataType;
  ptrArray = Array[1..4000] of dataptr;
  Arrayptr = ^ptrArray;

const
  null8=#0+#0+#0+#0+#0+#0+#0+#0;
  hdrstring='NES'+#26;
  dbasefile='ROMDBASE.DAT';
  cfgfile='NESTOY.CFG';
  missingfile='MISSING.TXT';
  version='2.1b';
  maxsize:Word = 4000;
  SortType:updown = ascending;
  extparamst:string='';
  dir_bad:string='Bad\';
  dir_unknown:string='Unknown\';
  dir_japan:string='Japan\';
  dir_usa:string='USA\';
  dir_europe:string='Europe\';
  dir_sweden:string='Sweden\';
  dir_canada:string='Canada\';
  dir_unlicensed:string='Unlicensed\';
  dir_vs:string='VS\';
  dir_pc10:string='Playchoice 10\';
  dir_dupes:string='Dupes\';
  dir_repair:string='Repair\';
  dir_trans:string='Translated\';
  dir_hacked:string='Hacked\';
  dir_pirate:string='Pirate\';
  move_bad:boolean=true;
  move_hacked:boolean=true;
  move_pirate:boolean=true;
  missing_bad:boolean=false;
  missing_hacked:boolean=true;
  missing_pirate:boolean=true;
  missing_trans:boolean=false;

var
  hdcsum:boolean;
  csumdbase:array[1..2500] of record
                                str:string[8];
                                flag:boolean;
                                resize:integer;
                              end;
  dirarray:array[1..4000] of pchar;
  FCPrg,FCChr:array[1..100] of byte;
  path:array[1..12] of string;
  clf:array[1..12] of string;
  dbasecount,FCCount,numpaths:integer;
  cpath,progpath:string;
  cfgparam:string;
  overwritemissing:boolean;

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
  pivot :datatype;
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
                 While strcomp(d[lower]^,pivot)<0 do inc(lower);
                 While strcomp(pivot,d[upper]^)<0 do dec(upper);
               end;
    descending:begin
                 While strcomp(d[lower]^,pivot)>0 do inc(lower);
                 While strcomp(pivot,d[upper]^)>0 do dec(upper);
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
  y:integer;
begin
  y:=wherey;
  write('Press any key to continue');
  repeat until keypressed=true;
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

function I2S(i: longint): string;
var
  s:string[11];
begin
  str(i,s);
  I2S:=s;
end;

function romstr(i:integer):string;
begin
  if i=1 then romstr:=' ROM' else romstr:=' ROMs';
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
  if s='J' then temp:=1;
  if s='U' then temp:=2;
  if s='JU' then temp:=3;
  if s='E' then temp:=4;
  if s='JE' then temp:=5;
  if s='UE' then temp:=6;
  if s='JUE' then temp:=7;
  if s='S' then temp:=8;
  if s='C' then temp:=16;
  if s='T' then temp:=96;
  if s='X' then temp:=97;
  if s='V' then temp:=98;
  if s='P' then temp:=99;
  countrys2i:=temp;
end;

function countryi2s(i:integer):string;
var
  temp:string[7];
begin
  temp:='';
  case i of
    1: temp:=' (J)';
    2: temp:=' (U)';
    3: temp:=' (JU)';
    4: temp:=' (E)';
    5: temp:=' (JE)';
    6: temp:=' (UE)';
    7: temp:=' (JUE)';
    8: temp:=' (S)';
    16: temp:=' (C)';
    97: temp:=' (UNL)';
    98: temp:=' (VS)';
    99: temp:=' (PC10)';
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
  slashflag:=false;
  fname:='';
  path:='';
  while pos('\',pathname)>0 do
    begin
      slashflag:=true;
      p:=pos('\',pathname);
      path:=path+copy(pathname,1,p);
      delete(pathname,1,p);
    end;
  if slashflag=false then
    if pos(':',pathname)>0 then
      begin
        p:=pos(':',pathname);
        path:=path+copy(pathname,1,p);
        delete(pathname,1,p);
      end;
  fname:=pathname;
  if path='' then path:='.\';
end;

function getsortdir(code:integer):string;
begin
  getsortdir:='';
  case code of
   -3:getsortdir:=dir_pirate;
   -2:getsortdir:=dir_hacked;
   -1:getsortdir:=dir_bad;
    0:getsortdir:=dir_unknown;
    1,5:getsortdir:=dir_japan;
    2,3,6,7:getsortdir:=dir_usa;
    4:getsortdir:=dir_europe;
    8:getsortdir:=dir_sweden;
    16:getsortdir:=dir_canada;
    96:getsortdir:=dir_trans;
    97:getsortdir:=dir_unlicensed;
    98:getsortdir:=dir_vs;
    99:getsortdir:=dir_pc10;
  end;
end;

procedure getcrc(fname:string;var retcrc:string;var garbage:boolean);
var
  crc:longint;
  f,result:word;
  buf:array[1..16384] of byte;
  ctr,g:integer;
begin
  garbage:=false;
  g:=0;
  crc:=crcseed;
  f:=LFNOpenFile(fname,FA_NORMAL,OPEN_RDONLY,1);
  result:=lfnblockread(f,buf,16);
  if hdcsum=true then
    for ctr:=1 to 16 do crc:=crc32(buf[ctr],crc);
  repeat
    result:=lfnblockread(f,buf,sizeof(buf));
    g:=result mod 8192;
    if g=512 then g:=0;
    if g>0 then garbage:=true;
    for ctr:=1 to result-g do crc:=crc32(buf[ctr],crc);
  until result=0;
  LFNCloseFile(f);
  crc:=crcend(crc);
  retcrc:=crchex(crc);
end;

procedure LFNMove(sourcepath,destpath,crc:string;var errcode:byte);
var
  sf,df,sresult,dresult,f:word;
  buf:array[1..16384] of byte;
  sp,sn,dp,dn:string;
  dirinfo:tfinddata;
  existb,garbage:boolean;
  ctr:integer;
  newcrc:string;

procedure parsedp;
begin
  if copy(dp,1,2)='.\' then delete(dp,1,2);
  if (dp[2]<>':') and (dp[1]<>'\') then dp:=cpath+dp;
  if dp[1]='\' then dp:=copy(cpath,1,2)+dp;
end;

begin
  errcode:=0;
  ctr:=0;
  splitpath(sourcepath,sn,sp);
  splitpath(destpath,dn,dp);
  sp:=getlongpathname(sp,false);
  parsedp;
  if upcasestr(sp)<>upcasestr(dp) then
    begin
      if dn='' then dn:=sn;
      sourcepath:=sp+sn;
      destpath:=dp+dn;
      if crc<>'' then
        if exist(destpath) then
          begin
            getcrc(destpath,newcrc,garbage);
            if newcrc=crc then
              begin
                dp:=dir_dupes;
                parsedp;
                destpath:=dp+dn;
              end;
          end;
      f:=LFNFindFirst(dp,FA_DIR,FA_DIR,dirinfo);
      if dos7error<>0 then LFNMkDir(copy(dp,1,length(dp)-1));
      LFNFindClose(f);
      sf:=LFNOpenFile(sourcepath,FA_RDONLY,OPEN_RDONLY,1);
      repeat
        ctr:=ctr+1;
        existb:=exist(destpath);
        if existb=true then
          begin
            if ctr<10 then delete(destpath,length(destpath),1);
            if ctr>=10 then delete(destpath,length(destpath)-1,2);
            destpath:=destpath+i2s(ctr);
          end;
      until existb=false;
      df:=LFNCreateFile(destpath,FA_NORMAL,OPEN_WRONLY,1);
      if dos7error<>0 then errcode:=1;
      if errcode=0 then
        repeat
          sresult:=lfnblockread(sf,buf,sizeof(buf));
          dresult:=lfnblockwrite(df,buf,sresult);
        until (sresult=0) or (sresult<>dresult);
        if dos7error=0 then LFNErase(sourcepath,FA_NORMAL,FA_NORMAL,False)
                       else errcode:=1;
      LFNCloseFile(df);
      LFNCloseFile(sf);
    end else errcode:=1;
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
  p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); dbaseinfo.chr:=x;
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
      if csumdbase[mid].str=cs then found:=true
        else if csumdbase[mid].str>cs then high:=mid
          else low:=mid;
    end;
  if found=true then fnd:=mid;
end;

procedure checkbanks(fname:string;prg:integer;chr:integer;var newprg:byte;var newchr:byte);
var
  prgcrc:array[1..128] of string[8];
  chrcrc:array[1..128] of string[8];
  crc:longint;
  f,result:word;
  fn:file;
  buf1:array[1..16384] of byte;
  buf2:array[1..8192] of byte;
  ctr,ctr2:integer;
  prgmatch,chrmatch:boolean;
begin
  if prg>128 then prg:=128;
  if chr>128 then chr:=128;
  prgmatch:=true;
  chrmatch:=true;
  f:=LFNOpenFile(fname,FA_NORMAL,OPEN_RDONLY,1);
  result:=lfnblockread(f,buf1,16);
  if prg>1 then
    for ctr:=1 to prg do
      begin
        crc:=crcseed;
        result:=lfnblockread(f,buf1,sizeof(buf1));
        for ctr2:=1 to result do crc:=crc32(buf1[ctr2],crc);
        crc:=crcend(crc);
        prgcrc[ctr]:=crchex(crc);
      end;
  if chr>1 then
    for ctr:=1 to chr do
      begin
        crc:=crcseed;
        result:=lfnblockread(f,buf2,sizeof(buf2));
        for ctr2:=1 to result do crc:=crc32(buf2[ctr2],crc);
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

procedure WriteNesHdr(fname:string;nhdr:neshdr;var errcode:byte);
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
        if g=512 then g:=0;
        if g>0 then result2:=result2-g;
        result:=lfnblockwrite(f,buf,result2);
      until (result2=0) or (result<>result2);
      LFNCloseFile(f);
      LFNCloseFile(f2);
    end;
end;

procedure CropRom(fname:string;nhdr:neshdr;var prg:byte;var chr:byte;newprg:byte;newchr:byte;var errcode:byte);
var
  f,f2,result,result2:word;
  hdr:array[1..16] of char;
  buf:array[1..16384] of char;
  buf2:array[1..8192] of char;
  tstr:string[16];
  c:integer;
  rfname:string;
  revprg,revchr:boolean;
begin
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
      for c:=1 to chr do
        begin
          result2:=lfnblockread(f2,buf2,sizeof(buf2));
          if (c<=newchr) and (revchr=false) then result:=lfnblockwrite(f,buf2,result2);
          if (c>newchr) and (revchr=true) then result:=lfnblockwrite(f,buf2,result2);
        end;
      LFNCloseFile(f);
      LFNCloseFile(f2);
      prg:=newprg;
      chr:=newchr;
    end;
end;

function readdir(pathname:string):word;
var
  count,counter,len:integer;
  dirinfo:tfinddata;
  f:word;
  strtemp:string;
  arraytemp:array[0..255] of char;
begin
  count:=0;
  f:=lfnfindfirst(pathname,FA_NORMAL,FA_NORMAL,dirinfo);
  while (dos7error=0) and (count<4000) do
    begin
      count:=count+1;
      strtemp:=dirinfo.name;
      len:=length(strtemp);
      for counter:=1 to len do arraytemp[counter-1]:=strtemp[counter];
        arraytemp[len]:=#0;
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
      writeln(f,'DIR_BAD = ',dir_bad);
      writeln(f,'DIR_CANADA = ',dir_canada);
      writeln(f,'DIR_DUPLICATES = ',dir_dupes);
      writeln(f,'DIR_EUROPE = ',dir_europe);
      writeln(f,'DIR_HACKED = ',dir_hacked);
      writeln(f,'DIR_JAPAN = ',dir_japan);
      writeln(f,'DIR_PC10 = ',dir_pc10);
      writeln(f,'DIR_PIRATE = ',dir_pirate);
      writeln(f,'DIR_SWEDEN = ',dir_sweden);
      writeln(f,'DIR_TRANS = ',dir_trans);
      writeln(f,'DIR_UNKNOWN = ',dir_unknown);
      writeln(f,'DIR_UNLICENSED = ',dir_unlicensed);
      writeln(f,'DIR_USA = ',dir_usa);
      writeln(f,'DIR_VS = ',dir_vs);
      writeln(f,'MOVE_BAD = ',move_bad);
      writeln(f,'MOVE_HACKED = ',move_hacked);
      writeln(f,'MOVE_PIRATE = ',move_pirate);
      writeln(f,'MISSING_BAD = ',missing_bad);
      writeln(f,'MISSING_HACKED = ',missing_hacked);
      writeln(f,'MISSING_PIRATE = ',missing_pirate);
      writeln(f,'MISSING_TRANS = ',missing_trans);
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
                begin
                  if s2='' then s2:='.\';
                  if s2[length(s2)]<>'\' then s2:=s2+'\';
                end;
              if s='DIR_BAD' then dir_bad:=s2;
              if s='DIR_CANADA' then dir_canada:=s2;
              if s='DIR_DUPLICATES' then dir_dupes:=s2;
              if s='DIR_EUROPE' then dir_europe:=s2;
              if s='DIR_HACKED' then dir_hacked:=s2;
              if s='DIR_JAPAN' then dir_japan:=s2;
              if s='DIR_PC10' then dir_pc10:=s2;
              if s='DIR_PIRATE' then dir_pirate:=s2;
              if s='DIR_SWEDEN' then dir_sweden:=s2;
              if s='DIR_TRANS' then dir_trans:=s2;
              if s='DIR_UNKNOWN' then dir_unknown:=s2;
              if s='DIR_UNLICENSED' then dir_unlicensed:=s2;
              if s='DIR_USA' then dir_usa:=s2;
              if s='DIR_VS' then dir_vs:=s2;
              if s='MOVE_BAD' then if upcasestr(s2)='FALSE' then move_bad:=false else
                if upcasestr(s2)='TRUE' then move_bad:=true;
              if s='MOVE_HACKED' then if upcasestr(s2)='FALSE' then move_hacked:=false else
                if upcasestr(s2)='TRUE' then move_hacked:=true;
              if s='MOVE_PIRATE' then if upcasestr(s2)='FALSE' then move_pirate:=false else
                if upcasestr(s2)='TRUE' then move_pirate:=true;
              if s='MISSING_BAD' then if upcasestr(s2)='FALSE' then missing_bad:=false else
                if upcasestr(s2)='TRUE' then missing_bad:=true;
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
end;

procedure loaddbase;
var
  f:text;
  s:string;
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
      csumdbase[dbasecount].str:=copy(s,1,8);
      csumdbase[dbasecount].flag:=false;
      csumdbase[dbasecount].resize:=0;
      if s[9]='*' then
        begin
          fccount:=fccount+1;
          csumdbase[dbasecount].resize:=fccount;
          p:=pos(';',s); delete(s,1,p);
          p:=pos(';',s); val(copy(s,1,p-1),FCPrg[fccount],code); delete(s,1,p);
          p:=pos(';',s); val(copy(s,1,p-1),FCChr[fccount],code); delete(s,1,p);
        end;
    end;
  close(f);
end;

function formatoutput(fname:string;minfo:neshdr;docsum:boolean;csum:string;rflag:integer;l:integer;view_bl:boolean):string;
var
  out:string;
  ns:string;
  split:boolean;
  fname2:string;
  c:char;
  count:integer;
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
      if minfo.country=0 then out:=out+' ???';
      if minfo.country=1 then out:=out+' '+'J  ';
      if minfo.country=2 then out:=out+' '+' U ';
      if minfo.country=3 then out:=out+' '+'JU ';
      if minfo.country=4 then out:=out+' '+'  E';
      if minfo.country=5 then out:=out+' '+'J E';
      if minfo.country=6 then out:=out+' '+' UE';
      if minfo.country=7 then out:=out+' '+'JUE';
      if minfo.country=8 then out:=out+' '+'  S';
      if minfo.country=16 then out:=out+' '+' C ';
      if minfo.country=96 then out:=out+' '+'TR ';
      if minfo.country=97 then out:=out+' '+'Unl';
      if minfo.country=98 then out:=out+' '+'VS ';
      if minfo.country=99 then out:=out+' '+'P10';
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
  flags:array[1..2500] of boolean;
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
  n1,n2:string;
  p,p2,t:integer;
begin
  n1:='';
  n2:='';
  t:=0;
  p:=pos('<',name);
  if p>0 then
    begin
      delete(name,p,1);
      if shorten=true then
        begin
          n1:=copy(name,1,p-1);
          delete(name,1,p-1);
          p2:=pos(',',name);
          if p2=0 then
            begin
              p2:=pos('(',name);
              if p2>0 then n1:=n1+' ';
            end;
          if p2>0 then
            n2:=copy(name,p2,length(name)-p2+1);
          name:=n1+n2;
        end;
    end;
  p:=pos('>',name);
  if p>0 then
    begin
      delete(name,p,1);
      if shorten=true then
        name:=copy(name,p,length(name)-p+1);
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
  dbasearray:array[1..2500] of pchar;
  charout:array[0..255] of char;
  volinfo:tvolinfo;
  missingpath:string;
  country:string[3];
  skipflag:boolean;

begin
  acount:=0;
  badcount:=0;
  getvolumeinformation(copy(cpath,1,3),volinfo);
  if volinfo.FSName='CDFS' then missingpath:=progpath
                           else missingpath:=getshortpathname(cpath,false);
  missingpath:=missingpath+missingfile;
  assign(f2,missingpath);
  {$I-}
  if overwritemissing=true then rewrite(f2) else
    begin
      reset(f2);
      io:=ioresult;
      if io>0 then rewrite(f2) else
        begin
          close(f2);
          parsemissing(missingpath);
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
          p:=pos(';',ts);
          if p=0 then fn:=ts else
            begin
              fn:=copy(ts,1,p-1);
              delete(ts,1,p);
            end;
          fn:=shortparse(fn,false);
          skipflag:=false;
          if (pos('(Bad Dump',fn)>0) and (missing_bad=false) then skipflag:=true;
          if ((pos('(Translated',fn)>0) or (pos('Translated)',fn)>0)) and (missing_trans=false) then skipflag:=true;
          if ((pos('(Hack',fn)>0) or (pos('Hack)',fn)>0)) and (missing_hacked=false) then skipflag:=true;
          if ((pos('(Pirate',fn)>0) or (pos('Pirate)',fn)>0)) and (missing_pirate=false) then skipflag:=true;
          if csumdbase[c].resize>0 then skipflag:=true;
          if skipflag=true then badcount:=badcount+1;
          if (csumdbase[c].flag=false) and (skipflag=false) then
            begin
              acount:=acount+1;
              p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); byte7:=x;
              p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); byte8:=x;
              p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); dbaseinfo.prg:=x;
              p:=pos(';',ts); ts2:=copy(ts,1,p-1); delete(ts,1,p); val(ts2,x,code); dbaseinfo.chr:=x;
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
      quicksort(dbasearray,1,acount);
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
      writeln(f2,acount,' missing',romstr(acount),' out of ',dbasecount-badcount);
      close(f);
      close(f2);
      for c:=acount downto 1 do
         strdispose(dbasearray[c]);
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
  writeln('NesToy ',version,' - (c)1999, D-Tox Software  (BETA Software, Use At Own Risk)');
  writeln;
if (t=0) or (t=1) then
  begin
    writeln('usage: NesToy [parameters] pathname1 [pathname2] [pathname3] ...');
    if t=0 then writeln;
  end;
if t=1 then
  begin
    writeln('Parameters:');
    writeln('-b             Display ROM and VROM by # of blocks instead of kB');
    writeln('-c             Calculate Checksums (CRC 32)');
    writeln('-hc            Calculate Checksums with header');
    writeln('-i             Outputs extended info if header or name are not correct');
    writeln('-o[file]       Sends output to file (DOS 8.3 filenames for now)');
    writeln('-ren[uscl]     Renames ROMs to names stored in database (enables -c)');
    writeln('                  u- Replace spaces with underscores');
    writeln('                  s- Remove spaces completely from filename');
    writeln('                  c- Attach country codes to end of filenames');
    writeln('                  l- Convert ROMs to all lowercase names');
    writeln('-sn            Use shorter names for some game titles');
    writeln('-rep,-repair   Repairs ROM headers with those found in database (enables -c)');
    writeln('-res,-resize   Automatically resizes ROMs if they contain duplicate banks');
    writeln('               of data.');
    writeln('-sort          Sorts ROMs into directories by country or type');
    writeln('-m#            Filter listing by mapper #');
    writeln('-f[hvbt4]      Filter listing by mapper data');
    writeln('                  h- Horizontal Mirroring     t- Trainer Present');
    writeln('                  v- Vertical Mirroring       4- 4 Screen Buffer');
    writeln('                  b- Contains SRAM (Battery backup)');
    pause;
    writeln('-u             Only display unknown ROMs (enables -c)');
    writeln('-missing[cbn]  Creates a list of missing ROMs in ',missingfile);
    writeln('                  c- Sort missing list by country');
    writeln('                  b- Bare listing (Name, country codes, and checksum only)');
    writeln('                  n- Force NesToy to create a new MISSING.TXT, even if one');
    writeln('                     already exists (It will be overwritten.)');
    writeln('-doall         Enables -c,-i,-ren,-repair,-resize,-sort, and -missing');
    writeln('-h,-?,-help    Displays this screen');
    writeln;
    writeln('Filename can include wildcards (*,?) anywhere inside the filename.  Long');
    writeln('file names are allowed.  If no filename is given, (*.nes) is assumed.');
    writeln('Up to 12 different pathnames may be specified.');
  end;
if t=2 then
  begin
    writeln('Error: You must specify a filename!');
    writeln;
  end;
if t=3 then
  begin
    writeln('NesToy only runs under Windows 95/98.');
    writeln;
  end;
  halt;
end;

var
  f:word;
  h,ns,csum:string;
  clfname,pathname,sortdir:string;
  nes,oldnes,resulthdr:NesHdr;
  byte7,byte8:byte;
  l,ctr,csumpos,sps,err:integer;
  msearch,rflag,counter:integer;
  romcount,matchcount,rncount,rpcount,rscount:integer;
  dbpos,io,pc:integer;
  fcpos:integer;
  docsum,show,show_h,show_v,show_b,show_4,show_t,view_bl,outfile,extout,unknown:boolean;
  rname,namematch,dbase,repair,cmp,abort,dbasemissing,garbage,sort:boolean;
  uscore,ccode,remspace,notrenamed,notrepaired,cropped,resize,sorted:boolean;
  booltemp,dupe,shortname,allmissing,missingsort,lowcasename:boolean;
  badrom,hackedrom,piraterom:boolean;
  result,rtmp:string;
  key:char;
  out,out2:string;
  outm:string[13];
  ofile:text;
  errcode:byte;
  name:string;
  volinfo:tvolinfo;
  newprg,newchr:byte;
  sortcode:integer;

begin
  checkbreak:=false;
  if IsDOS70=false then usage(3);
  cfgparam:='';
  progpath:=paramstr(0);
  while copy(progpath,length(progpath),1)<>'\' do
    delete(progpath,length(progpath),1);
  loaddbase;
  loadcfgfile;
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
  docsum:=false;
  hdcsum:=false;
  rname:=false;
  uscore:=false;
  ccode:=false;
  remspace:=false;
  unknown:=false;
  dbase:=false;
  repair:=false;
  resize:=false;
  abort:=false;
  dbasemissing:=false;
  sort:=false;
  dupe:=false;
  shortname:=false;
  allmissing:=true;
  missingsort:=false;
  lowcasename:=false;
  overwritemissing:=false;
  msearch:=-1;
  if extparamcount=0 then usage(0);
  searchps('-h',sps,result);
  if sps>0 then usage(1);
  searchps('-?',sps,result);
  if sps>0 then usage(1);
  searchps('-help',sps,result);
  if sps>0 then usage(1);
  for pc:=1 to extparamcount do
    begin
      clfname:=extparamstr(pc);
      if (clfname[1]<>'-') and (numpaths<12) then
        begin
          numpaths:=numpaths+1;
          splitpath(clfname,clfname,pathname);
          if clfname='' then clfname:='*.nes';
          clf[numpaths]:=clfname;
          path[numpaths]:=pathname;
        end;
    end;
  if numpaths=0 then usage(2);
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
    end;
  searchps('-sn',sps,result);
  if sps>0 then shortname:=true;
  searchps('-o*',sps,result);
  if sps>0 then
    begin
      outfile:=true;
      if result='' then result:='OUTPUT.TXT';
      getvolumeinformation(copy(cpath,1,3),volinfo);
      if volinfo.FSName='CDFS' then result:=progpath+result
                               else result:=getshortpathname(cpath,false)+result;
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
  searchps('-rep',sps,result);
  if sps>0 then begin repair:=true; extout:=true; docsum:=true end;
  searchps('-repair',sps,result);
  if sps>0 then begin repair:=true; extout:=true; docsum:=true end;
  searchps('-res',sps,result);
  if sps>0 then begin resize:=true; extout:=true; docsum:=true; end;
  searchps('-resize',sps,result);
  if sps>0 then begin resize:=true; extout:=true; docsum:=true; end;
  searchps('-i',sps,result);
  if sps>0 then begin extout:=true; docsum:=true; end;
  searchps('-u',sps,result);
  if sps>0 then begin unknown:=true; docsum:=true; end;
  searchps('-missing*',sps,result);
  if sps>0 then
    begin
      dbasemissing:=true;
      docsum:=true;
      if pos('C',result)>0 then missingsort:=true;
      if pos('B',result)>0 then allmissing:=false;
      if pos('N',result)>0 then overwritemissing:=true;
    end;
  searchps('-sort',sps,result);
  if sps>0 then begin sort:=true; docsum:=true; end;
  searchps('-doall',sps,result);
  if sps>0 then begin
                  docsum:=true; rname:=true; repair:=true; resize:=true; extout:=true;
                  dbasemissing:=true; sort:=true;
                end;
  searchps('-dbase',sps,result);
  if sps>0 then begin
                  dbase:=true; docsum:=true; extout:=false; sort:=false; unknown:=false;
                  rname:=false; repair:=false; resize:=false; dbasemissing:=false;
                end;
  if docsum=false then l:=55 else l:=40;
  for pc:=1 to numpaths do
    begin
      pathname:=getfullpathname(path[pc],false);
      clfname:=clf[pc];
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
            hackedrom:=false;
            piraterom:=false;
            sorted:=false;
            fcpos:=0;
            h:=ReadNesHdr(Name);
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
                getcrc(Name,csum,garbage);
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
                        if FCPos=0 then checkbanks(Name,nes.prg,nes.chr,newprg,newchr);
                        if FCPos>0 then begin newprg:=fcprg[fcpos]; newchr:=fcchr[fcpos]; end;
                        if (nes.prg<>newprg) or (nes.chr<>newchr) then
                          begin
                            oldnes:=nes;
                            CropRom(Name,nes,nes.prg,nes.chr,newprg,newchr,errcode);
                            if errcode=0 then
                              begin
                                if copy(name,length(name)-3,1)='.' then rtmp:=copy(name,1,length(name)-4);
                                LFNMove(rtmp+'.ba~','Backup\'+rtmp+'.bak','',errcode);
                                rscount:=rscount+1;
                                cropped:=true;
                                getcrc(Name,csum,garbage);
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
                    if nes.vs=1 then nes.country:=98;
                    if nes.pc10=1 then nes.country:=99;
                  end;
                if dbpos>0 then
                  begin
                    if csumdbase[dbpos].flag=true then dupe:=true;
                    csumdbase[dbpos].flag:=true;
                  end;
                if unknown=true then show:=false;
                if (unknown=true) and (dbpos=0) then show:=true;
              end;
            if show=true then
              begin
                if docsum=true then rflag:=1 else rflag:=-1;
                romcount:=romcount+1;
                if (dbpos=0) and (badrom=true) then rflag:=6;
                if (dbpos>0) and (dbase=false) then
                  begin
                    rflag:=2;
                    matchcount:=matchcount+1;
                    getdbaseinfo(dbpos,result,resulthdr);
                    result:=shortparse(result,shortname);
                    if pos('(Bad Dump',result)>0 then badrom:=true;
                    if (pos('(Hack',result)>0) or (pos('Hack)',result)>0) then hackedrom:=true;
                    if (pos('(Pirate',result)>0) or (pos('Pirate)',result)>0) then piraterom:=true;
                    if (resulthdr.vs=1) and (resulthdr.pc10=1) then
                      begin
                        writeln('ERROR IN DATABASE 01 -- ',csumdbase[dbpos].str,' ',result); {Has both VS and PC10 bits set}
                        halt;
                      end;
                    nes.country:=resulthdr.country;
                    nes.company:=resulthdr.company;
                    if ccode=true then result:=result+countryi2s(nes.country);
                    if lowcasename=true then result:=lowcasestr(result);
                    if remspace=true then result:=spcvt(result,2);
                    if uscore=true then result:=spcvt(result,1);
                    cmp:=comparehdrs(nes,resulthdr);
                    if result+'.nes'<>name then namematch:=false else namematch:=true;
                    if (namematch=false) and (rname=false) then
                      begin
                        rtmp:=result;
                        if name=lowcasestr(name) then rtmp:=lowcasestr(rtmp);
                        if rtmp+'.nes'=name then namematch:=true else
                        if spcvt(rtmp,1)+'.nes'=name then namematch:=true else
                        if spcvt(rtmp,2)+'.nes'=name then namematch:=true else
                          begin
                            rtmp:=result+countryi2s(nes.country);
                            if name=lowcasestr(name) then rtmp:=lowcasestr(rtmp);
                            if rtmp+'.nes'=name then namematch:=true else
                            if spcvt(rtmp,1)+'.nes'=name then namematch:=true else
                            if spcvt(rtmp,2)+'.nes'=name then namematch:=true
                          end;
                      end;
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
                          out:=formatoutput(name,oldnes,docsum,' Resized',1,l,view_bl);
                          checksplit(out,out2);
                          writeln(out);
                          if out2<>'' then writeln(out2);
                          if outfile=true then
                            begin
                              writeln(ofile,out);
                              if out2<>'' then writeln(ofile,out2);
                            end;
                        end;
                      out:=formatoutput(name,nes,docsum,csum,rflag,l,view_bl);
                      checksplit(out,out2);
                    end
                  else
                    begin
                      out:=out+csum+';'+name;
                      if copy(out,length(out)-3,1)='.' then out:=copy(out,1,length(out)-4);
                      byte7:=nes.mirror+nes.sram*2+nes.trainer*4+nes.fourscr*8+nes.mapper mod 16*16;
                      byte8:=nes.vs+nes.pc10*2+nes.mapper div 16*16;
                      out:=out+';'+i2s(byte7);
                      out:=out+';'+i2s(byte8);
                      out:=out+';'+i2s(nes.prg);
                      out:=out+';'+i2s(nes.chr);
                    end;
                sortcode:=nes.country;
                if (badrom=true) and (move_bad=true) then sortcode:=-1;
                if (hackedrom=true) and (move_hacked=true) then sortcode:=-2;
                if (piraterom=true) and (move_pirate=true) then sortcode:=-3;
                writeln(out);
                if out2<>'' then writeln(out2);
                if outfile=true then
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
                            LFNMove(rtmp+'.ba~','Backup\'+rtmp+'.bak','',errcode);
                          end;
                        if errcode>0 then notrepaired:=true;
                      end;
                    if (rname=true) and (dupe=false) and (sort=false) then
                      if result+'.nes'<>name then
                        begin
                          booltemp:=false;
                          if upcasestr(result+'.nes')=upcasestr(name) then booltemp:=true;
                          if (exist(result+'.nes')) and (booltemp=false) then
                            begin
                              LFNRename(name,result+countryi2s(nes.country)+'.nes');
                              errcode:=dos7error;
                              if errcode=0 then name:=result+countryi2s(nes.country)+'.nes';
                            end
                          else
                            begin
                              LFNRename(name,result+'.nes');
                              errcode:=dos7error;
                              if errcode=0 then name:=result+'.nes';
                            end;
                          if errcode=0 then rncount:=rncount+1 else notrenamed:=true;
                        end;
                    if (rname=true) and (dupe=false) and (sort=true) then
                      if result+'.nes'<>name then
                        begin
                           sorted:=true;
                           sortdir:=getsortdir(sortcode);
                           if notrepaired=true then sortdir:=dir_repair;
                           LFNMove(name,sortdir+result+'.nes',csum,errcode);
                           if errcode=0 then rncount:=rncount+1 else notrenamed:=true;
                        end;
                    if (extout=true) and ((cmp=false) or (namematch=false) or (garbage=true)) then
                      begin
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
                        if (rname=true) and (namematch=false) then
                          if notrenamed=true then outm:=' Can''t Rename';
                        if (repair=true) and (cmp=false) then
                          if notrepaired=true then outm:=' Can''t Repair';
                        out:=out+outm;
                        writeln(out);
                        if out2<>'' then writeln(out2);
                        writeln;
                        if outfile=true then
                          begin
                            writeln(ofile,out);
                            if out2<>'' then writeln(ofile,out2);
                            writeln(ofile);
                          end;
                      end;
                  end;
                if dupe=true then
                  if (rname=true) and (result+'.nes'<>name) then
                    begin
                      LFNMove(name,dir_dupes+result+'.nes','',errcode);
                      if errcode=0 then rncount:=rncount+1;
                    end else LFNMove(name,dir_dupes,'',errcode);
                if (sort=true) and (dupe=false) and (sorted=false) then
                  begin
                    sortdir:=getsortdir(sortcode);
                    if notrepaired=true then sortdir:=dir_repair;
                    LFNMove(name,sortdir,csum,errcode);
                  end;
              end;
          end;
        LFNChDir(cpath);
      end;
      readdirclose(f);
    end;
  if romcount=0 then writeln('No ROMs found') else begin writeln; writeln(romcount,romstr(romcount),' found'); end;
  if matchcount>0 then writeln(matchcount,romstr(matchcount),' found in database');
  if rpcount>0 then writeln(rpcount,romstr(rpcount),' repaired');
  if rncount>0 then writeln(rncount,romstr(rncount),' renamed');
  if rscount>0 then writeln(rscount,romstr(rscount),' resized');
  if (outfile=true) and (dbase=false) then
    begin
      if romcount=0 then writeln(ofile,'No ROMs found')
      else begin writeln(ofile); writeln(ofile,romcount,romstr(romcount),' found'); end;
      if matchcount>0 then writeln(ofile,matchcount,romstr(matchcount),' found in database');
      if rpcount>0 then writeln(ofile,rpcount,romstr(rpcount),' repaired');
      if rncount>0 then writeln(ofile,rncount,romstr(rncount),' renamed');
      if rscount>0 then writeln(ofile,rscount,romstr(rscount),' resized');
    end;
  if outfile=true then close(ofile);
  if dbasemissing=true then listmissing(allmissing,missingsort);
end.
