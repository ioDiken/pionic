#!/usr/bin/env python

# A tiny CGI server 

# Subclass CGITTPREquestHandler to properly return "Status: XXX" headers or
# status 500 if a cgi script has non-zero exit status or writes to stderr
import BaseHTTPServer
from CGIHTTPServer import CGIHTTPRequestHandler
from cStringIO import StringIO
import sys, os, getopt, re

# die with a message
def die(format, *args):
    sys.stderr.write((format+"\r\n") % args)
    sys.exit(1)

class mycgi(CGIHTTPRequestHandler):
    # no special treatment for *.py
    def is_python(self, path):
        return False
  
    # never return file content
    def is_cgi(self):
        self.cgi_info = '', self.path[1:]
        return True

    # swallow logs if quiet
    def log_message(self, format, *args):
        if not self.quiet: 
            CGIHTTPRequestHandler.log_message(self, format, *args)

    # remember first log_error, so stderr output error has priority over exit code
    def log_error(self, format, *args):
        if self.logged is None:
            self.logged=(format%args).strip()
        self.log_message(self, format, *args)
        
    def run_cgi(self):
        self.wsave=self.wfile                               # replace output file with stringIO 
        self.wfile=StringIO()                     
        self.have_fork=False                                # force cgi to run with popen
        self.logged=None                                    # assume no errors will be logged
        CGIHTTPRequestHandler.run_cgi(self)                 
        self.wfile.seek(0)                    
        status=self.wfile.readline()                        # get status line
        rewind=self.wfile.tell()                            # remember rewind position
        if status.split(' ')[1].strip() == '200':           # if 'normal' exit
            if self.logged is not None:
                # run_cgi invoked log_error, return as status 500 
                status='%s 500 %s\r\n' % (self.protocol_version, self.logged)
            else:
                # scan headers
                for line in self.wfile:
                    if line.strip() == '': 
                        # end of headers
                        break
                    if not re.match('^\S+:.*\S',line):
                        # require form 'key: value'
                        status=self.protocol_version + ' 500 malformed header\r\n'
                        break;
                    if line.startswith('Status:'):
                        # if 'Status: something', use it
                        status='%s %s\r\n' % (self.protocol_version, line.split(':',1)[1].strip())
        
        self.wfile.seek(rewind)
        self.wsave.write(status)
        self.wsave.write(self.wfile.read())

# parse options
try:
    opts, args = getopt.getopt(sys.argv[1:],'d:p:b:l')
    assert len(args)==0
except:
    die("""Usage:

    cgiserver.py [options]

Serve cgi scripts via http. Where options are:

    -d directory    - directory to serve files from, default is current directory
    -p port         - port to listen on, default is 8000
    -b ad.dr.es.s   - IP address to bind to, default is don't bind
    -l              - enable logging on stdout
""")

handler=mycgi
handler.quiet=True

bind=""
port=8000
for opt, arg in opts:
    if opt == '-d': 
        try:
            os.chdir(arg)
        except:
            die("Invalid root '%s'",arg)

    if opt == '-p': 
        try:
            port=int(arg)
            assert 0<port<65536
        except:
            die("Invalid port '%s'", arg)
    
    if opt == '-b':
        bind=arg
        try:
            assert bind.count(".") == 3
            for octet in bind.split('.'):
                assert 0<=int(octet)<=255
        except:
            die("Invalid bind address '%s'", arg)

    if opt == '-l':
        handler.quiet=False

# delete environment
for v in [k for k in os.environ]:
    del os.environ[v]

if not handler.quiet:
    print("Listening for requests on %s port %d in %s..."%("all interfaces" if bind=="" else bind, port, os.getcwd()))

BaseHTTPServer.HTTPServer((bind,port),mycgi).serve_forever()
