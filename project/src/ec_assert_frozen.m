function ec_assert_frozen(root)
m=jsondecode(fileread(fullfile(root,'provenance','code_manifest.json')));
for k=1:numel(m.files)
    f=fopen(fullfile(root,m.files(k).path),'rb'); assert(f>=0,'EC:Frozen','Missing frozen file.');
    bytes=fread(f,inf,'*uint8'); fclose(f);
    md=java.security.MessageDigest.getInstance('SHA-256'); md.update(bytes);
    actual=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
    assert(strcmp(actual,m.files(k).sha256),'EC:Frozen','Changed frozen file: %s',m.files(k).path);
end
end
