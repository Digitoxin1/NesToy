program NesToy;
{$X+}
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
  ptrArray = Array[1..3000] of dataptr;
  Arrayptr = ^ptrArray;

const
  null8=#0+#0+#0+#0+#0+#0+#0+#0;
  hdrstring='NES'+#26;
  dbasefile='ROMDBASE.DAT';
  version='1.2b';
  maxsize:Word = 3000;
  SortType:updown = ascending;

var
  hdcsum:boolean;
  csumdbase:array[1..2500] of record
                                str:string[8];
                                flag:boolean;
                              end;
  dirarray:array[1..3000] of pchar;
  path:array[1..12] of string;
  clf:array[1..12] of string;
  dbasecount,numpaths:integer;
  cpath,progpath:string;

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

function I2S(i: longint): string;
var
  s:string[11];
begin
  str(i,s);
  I2S:=s;
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

function paramstrparse:string;
var
  s1,s2:string;
  counter:integer;
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
  paramstrparse:=s1;
end;

function extparamcount:integer;
var
  s:string;
  i:integer;
begin
  i:=0;
  s:=paramstrparse;
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
  s1:=paramstrparse;
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
    9: temp:=' (C)';
    97: temp:=' (UNL)';
    98: temp:=' (VS)';
    99: temp:=' (PC10)';
  end;
  countryi2s:=temp;
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

procedure LFNMove(sourcepath,destpath:string;var errcode:byte);
var
  sf,df,sresult,dresult,f:word;
  buf:array[1..16384] of byte;
  sp,sn,dp,dn:string;
  dirinfo:tfinddata;
begin
  errcode:=0;
  splitpath(sourcepath,sn,sp);
  splitpath(destpath,dn,dp);
  if dn='' then dn:=sn;
  if copy(dn,length(dn)-3,4)='.ne~' then dn[length(dn)]:='s';
  sourcepath:=sp+sn;
  destpath:=dp+dn;
  f:=LFNFindFirst(dp,FA_DIR,FA_DIR,dirinfo);
  if dos7error<>0 then LFNMkDir(copy(dp,1,length(dp)-1));
  LFNFindClose(f);
  sf:=LFNOpenFile(sourcepath,FA_RDONLY,OPEN_RDONLY,1);
  df:=LFNCreateFile(destpath,FA_NORMAL,OPEN_WRONLY,1);
  if errcode=0 then
    repeat
      sresult:=lfnblockread(sf,buf,sizeof(buf));
      dresult:=lfnblockwrite(df,buf,sresult);
    until (sresult=0) or (sresult<>dresult);
    if dos7error=0 then LFNErase(sourcepath,FA_NORMAL,FA_NORMAL,False);
  LFNCloseFile(df);
  LFNCloseFile(sf);
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

procedure getcrc(fname:string;var retcrc:string;var garbage:boolean);
var
  crc:longint;
  f,result:word;
  fn:file;
  buf:array[1..16384] of byte;
  ctr,g:integer;
begin
  garbage:=false;
  g:=0;
  crc:=crcseed;
  f:=LFNOpenFile(fname,FA_NORMAL,OPEN_RDONLY,1);
  if hdcsum=false then result:=lfnblockread(f,buf,16);
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

procedure WriteNesHdr(fname:string;nhdr:neshdr);
var
  f,f2,result,result2:word;
  hdr:array[1..16] of char;
  buf:array[1..16384] of char;
  tstr:string[16];
  c,g:integer;
  rfname:string;
begin
  rfname:=fname;
  if copy(rfname,length(fname)-3,1)='.' then rfname:=copy(fname,1,length(fname)-4);
  rfname:=rfname+'.ba~';
  LFNRename(fname,rfname);
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
  while (dos7error=0) and (count<3000) do
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

procedure loaddbase;
var
  f:text;
  s:string[8];
begin
  dbasecount:=0;
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
      csumdbase[dbasecount].str:=s;
      csumdbase[dbasecount].flag:=false;
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
      if (minfo.vs=0) and (minfo.pc10=0) then
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
          if minfo.country=97 then out:=out+' '+'Unl';
        end;
      if (minfo.country=98) or (minfo.vs=1) then out:=out+' '+'VS ';
      if (minfo.country=99) or (minfo.pc10=1) then out:=out+' '+'P10';
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

procedure cleanrn(rn,rp:integer);
var
  f:word;
  DirInfo:SearchRec;
  s,ps,fs:string;
  errcode:byte;
begin
  if rn>0 then
    begin
      findfirst('*.ne~',Archive,DirInfo);
      while DosError = 0 do
        begin
          s:=getlongpathname(dirinfo.name,false);
          s:=copy(s,1,length(s)-4)+'.nes';
          LFNRename(DirInfo.name,s);
          FindNext(DirInfo);
        end;
    end;
  if rp>0 then
    begin
      findfirst('*.ba~',Archive,DirInfo);
      while DosError = 0 do
        begin
          s:=getlongpathname(dirinfo.name,false);
          s:=copy(s,1,length(s)-4)+'.bak';
          splitpath(s,fs,ps);
          LFNMove(DirInfo.name,'Backup\'+fs,errcode);
          FindNext(DirInfo);
        end;
    end;
end;

procedure listmissing;
var
  f,f2:text;
  io,c,p,x,code,acount:integer;
  counter:integer;
  byte7,byte8:byte;
  ts,ts2,fn,out,out2:string;
  dbaseinfo:neshdr;
  csum:string[8];
  dbasearray:array[1..2500] of pchar;
  charout:array[0..255] of char;
begin
  acount:=0;
  assign(f2,cpath+'\MISSING.TXT');
  {$I-}
  reset(f2);
  {$I+}
  io:=ioresult;
  if io>0 then rewrite(f2) else append(f2);
  if io=0 then begin
                 writeln(f2);
                 writeln(f2,'------------------------------------------------------------------------------');
               end;
  assign(f,progpath+dbasefile);
  reset(f);
  for c:=1 to dbasecount do
    begin
      readln(f,ts);
      if csumdbase[c].flag=false then
        begin
          acount:=acount+1;
          p:=pos(';',ts); csum:=copy(ts,1,p-1); delete(ts,1,p);
          p:=pos(';',ts);
          if p=0 then fn:=ts else
            begin
              fn:=copy(ts,1,p-1);
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
          out:=formatoutput(fn,dbaseinfo,true,csum,0,41,false);
          delete(out,1,2);
          for counter:=1 to length(out) do charout[counter-1]:=out[counter];
          charout[counter]:=#0;
          dbasearray[acount]:=strnew(charout);
        end;
    end;
  quicksort(dbasearray,1,acount);
  for c:=1 to acount do
    begin
      out:=strpas(dbasearray[c]);
      checksplit(out,out2);
      writeln(f2,out);
      if out2<>'' then writeln(f2,out2);
    end;
  writeln(f2);
  writeln(f2,acount,' missing roms out of ',dbasecount);
  close(f);
  close(f2);
  for c:=acount downto 1 do
     strdispose(dbasearray[c]);
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
    writeln('-ren[usc]      Renames roms to names stored in database (enables -c)');
    writeln('                  u- Replace spaces with underscores');
    writeln('                  s- Remove spaces completely from filename');
    writeln('                  c- Attach country codes to end of filenames');
    writeln('-rep,-repair   Repairs rom headers with those found in database (enables -c)');
    writeln('-m#            Filter listing by mapper #');
    writeln('-f[hvbt4]      Filter listing by mapper data');
    writeln('                  h- Horizontal Mirroring     t- Trainer Present');
    writeln('                  v- Vertical Mirroring       4- 4 Screen Buffer');
    writeln('                  b- Contains SRAM (Battery backup)');
    writeln('-u             Only display unknown roms (enables -c)');
    writeln('-missing       Creates a list of missing roms in MISSING.TXT');
    writeln('-sort          Sorts ROMS into directories by country or type');
    writeln('-h,-?,-help    Displays this screen');
    writeln;
    pause;
    writeln('Filename can include wildcards (*,?) anywhere inside the filename.  Long');
    writeln('file names are allowed.  If no filename is given, (*.nes) is assumed.');
    writeln('Up to 8 different pathnames may be specified.');
  end;
if t=2 then
  begin
    writeln('error: You must specify a filename!');
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
  nes,resulthdr:NesHdr;
  byte7,byte8:byte;
  l,ctr,csumpos,sps,err:integer;
  msearch,rflag,counter:integer;
  romcount,matchcount,rncount,rpcount:integer;
  dbpos,io,pc:integer;
  docsum,show,show_h,show_v,show_b,show_4,show_t,view_bl,outfile,extout,unknown:boolean;
  rname,namematch,dbase,repair,cmp,abort,dbasemissing,garbage,sort:boolean;
  uscore,ccode,remspace,dupe:boolean;
  result,rtmp:string;
  key:char;
  out,out2:string;
  outm:string[13];
  ofile:text;
  errcode:byte;
  name:string;

begin
  checkbreak:=false;
  if IsDOS70=false then usage(3);
  progpath:=paramstr(0);
  while copy(progpath,length(progpath),1)<>'\' do
    delete(progpath,length(progpath),1);
  loaddbase;
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
  docsum:=false;
  hdcsum:=false;
  rname:=false;
  uscore:=false;
  ccode:=false;
  remspace:=false;
  unknown:=false;
  dbase:=false;
  repair:=false;
  abort:=false;
  dbasemissing:=false;
  sort:=false;
  dupe:=false;
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
    end;
  searchps('-o*',sps,result);
  if sps>0 then
    begin
      outfile:=true;
      if result='' then result:='OUTPUT.TXT';
      assign(ofile,cpath+result);
      {$I-}
      reset(ofile);
      {$I+}
      io:=ioresult;
      if io>0 then rewrite(ofile) else append(ofile);
      if io=0 then begin
                     writeln(ofile);
                     writeln(ofile,'------------------------------------------------------------------------------');
                   end;
    end;
  searchps('-rep',sps,result);
  if sps>0 then begin repair:=true; extout:=true; docsum:=true end;
  searchps('-repair',sps,result);
  if sps>0 then begin repair:=true; extout:=true; docsum:=true end;
  searchps('-i',sps,result);
  if sps>0 then begin extout:=true; docsum:=true; end;
  searchps('-u',sps,result);
  if sps>0 then begin unknown:=true; docsum:=true; end;
  searchps('-dbase',sps,result);
  if sps>0 then begin dbase:=true; docsum:=true; extout:=false; end;
  searchps('-missing',sps,result);
  if sps>0 then begin dbasemissing:=true; end;
  searchps('-sort',sps,result);
  if sps>0 then begin sort:=true; end;
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
                if key=#3 then abort:=true;
              end;
            show:=true;
            garbage:=false;
            dupe:=false;
            if copy(Name,length(Name)-3,4)='.ne~' then show:=false;
            if copy(Name,length(Name)-3,4)='.ba~' then show:=false;
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
                if (dbpos>0) and (dbase=false) then
                  begin
                    rflag:=2;
                    matchcount:=matchcount+1;
                    getdbaseinfo(dbpos,result,resulthdr);
                    if (resulthdr.vs=1) and (resulthdr.pc10=1) then
                      begin
                        writeln('ERROR IN DATABASE 01 -- ',csumdbase[dbpos].str,' ',result); {Has both VS and PC10 bits set}
                        halt;
                      end;
                    nes.country:=resulthdr.country;
                    nes.company:=resulthdr.company;
                    if ccode=true then result:=result+countryi2s(nes.country);
                    if remspace=true then result:=spcvt(result,2);
                    if uscore=true then result:=spcvt(result,1);
                    cmp:=comparehdrs(nes,resulthdr);
                    if result+'.nes'<>name then namematch:=false else namematch:=true;
                    if (namematch=false) and (rname=false) then
                      begin
                        rtmp:=result+countryi2s(nes.country);
                        if spcvt(result,1)+'.nes'=name then namematch:=true else
                        if spcvt(result,2)+'.nes'=name then namematch:=true else
                        if rtmp+'.nes'=name then namematch:=true else
                        if spcvt(rtmp,1)+'.nes'=name then namematch:=true else
                        if spcvt(rtmp,2)+'.nes'=name then namematch:=true;
                      end;
                    if namematch=false then rflag:=4;
                    if (cmp=false) or (garbage=true) then rflag:=3;
                    if dupe=true then rflag:=5;
                  end;
                if dbase=false
                  then
                    begin
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
                        rpcount:=rpcount+1;
                        WriteNesHdr(name,resulthdr);
                      end;
                    if (rname=true) and (dupe=false) then
                      if result+'.nes'<>name then
                        begin
                          rncount:=rncount+1;
                          LFNRename(name,result+'.ne~');
                          name:=result+'.ne~';
                        end;
                    if (extout=true) and ((cmp=false) or (namematch=false) or (garbage=true)) then
                      begin
                        out:=formatoutput(result,resulthdr,false,'',0,l,view_bl);
                        checksplit(out,out2);
                        outm:='   Bad [----]';
                        if namematch=false then outm[9]:='N';
                        if cmp=false then outm[10]:='H';
                        if nes.other<>null8 then outm[11]:='G';
                        if (nes.vs=1) and (nes.pc10=1) then outm[11]:='G';
                        if garbage=true then outm[12]:=+'F';
                        if (rname=true) and (namematch=false) then outm:='      Renamed';
                        if (repair=true) and (cmp=false) then outm:='     Repaired';
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
                  LFNMove(name,'Dupes\',errcode);
                if (sort=true) and (dupe=false) then
                  begin
                    sortdir:='';
                    if (nes.country=1) or (nes.country=5) then sortdir:='Japan\';
                    if (nes.country=2) or (nes.country=3) or
                       (nes.country=6) or (nes.country=7) then sortdir:='USA\';
                    if nes.country=4 then sortdir:='Europe\';
                    if nes.country=16 then sortdir:='Canada\';
                    if nes.country=8 then sortdir:='Sweden\';
                    if nes.country=0 then sortdir:='Unknown\';
                    if nes.country=97 then sortdir:='Unlicensed\';
                    if (nes.country=99) or (nes.pc10=1) then sortdir:='Playchoice 10\';
                    if (nes.country=98) or (nes.vs=1) then sortdir:='VS\';
                    LFNMove(name,sortdir,errcode);
                  end;
              end;
          end;
        if (rname=true) or (repair=true) then cleanrn(rncount,rpcount);
        LFNChDir(cpath);
      end;
      readdirclose(f);
    end;
  if romcount=0 then writeln('No roms found') else begin writeln; writeln(romcount,' roms found'); end;
  if matchcount>0 then writeln(matchcount,' roms found in database');
  if rpcount>0 then writeln(rpcount, ' rom headers repaired');
  if rncount>0 then writeln(rncount, ' roms renamed');
  if (outfile=true) and (dbase=false) then
    begin
      if romcount=0 then writeln(ofile,'No roms found')
      else begin writeln(ofile); writeln(ofile,romcount,' roms found'); end;
      if matchcount>0 then writeln(ofile,matchcount,' roms found in database');
      if rpcount>0 then writeln(ofile,rpcount, ' rom headers repaired');
      if rncount>0 then writeln(ofile,rncount, ' roms renamed');
    end;
  if outfile=true then close(ofile);
  if dbasemissing=true then listmissing;
end.
