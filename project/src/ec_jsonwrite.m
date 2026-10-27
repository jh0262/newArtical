function ec_jsonwrite(path,value)
f=fopen(path,'w','n','UTF-8'); assert(f>=0,'EC:File','Cannot open %s',path);
clean=onCleanup(@()fclose(f));
fprintf(f,'%s',jsonencode(value,'PrettyPrint',true));
end
