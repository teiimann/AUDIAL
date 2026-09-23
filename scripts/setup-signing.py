#!/usr/bin/env python3
"""One-time local code-signing identity setup. Requires explicit user authorization."""
import os, pathlib, secrets, subprocess, tempfile
name = 'DIALITO Local Development'
root = pathlib.Path.home() / 'Library/Application Support/DIALITO/Signing'
root.mkdir(parents=True, exist_ok=True)
cert = root / 'development.cer'
keychain = pathlib.Path.home() / 'Library/Keychains/login.keychain-db'
def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL)
if not cert.exists():
    with tempfile.TemporaryDirectory(prefix='dialito-signing-') as folder:
        d = pathlib.Path(folder)
        password = secrets.token_urlsafe(32)
        config = d / 'certificate.cnf'
        config.write_text('[req]\ndistinguished_name=dn\nx509_extensions=extensions\nprompt=no\n[dn]\nCN='+name+'\n[extensions]\nbasicConstraints=critical,CA:false\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\nsubjectKeyIdentifier=hash\n')
        run(['openssl','req','-new','-newkey','rsa:3072','-nodes','-x509','-days','3650','-config',str(config),'-keyout',str(d/'key.pem'),'-out',str(d/'cert.pem')])
        run(['openssl','pkcs12','-export','-legacy','-inkey',str(d/'key.pem'),'-in',str(d/'cert.pem'),'-name',name,'-out',str(d/'identity.p12'),'-passout','pass:'+password])
        run(['security','import',str(d/'identity.p12'),'-k',str(keychain),'-P',password,'-T','/usr/bin/codesign'])
        run(['openssl','x509','-in',str(d/'cert.pem'),'-outform','DER','-out',str(cert)])
# User-domain trust, restricted to code-signing policy; never TLS or system trust.
run(['security','add-trusted-cert','-r','trustRoot','-p','codeSign','-k',str(keychain),str(cert)])
print('DIALITO signing identity installed; private key remains in login Keychain.')
