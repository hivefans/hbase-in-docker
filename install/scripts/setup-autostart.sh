#!/bin/bash

echo '#!/bin/bash

sudo -u hadoop bash /home/hadoop/setup/autostart.sh

exit 0
' > /etc/rc.local

chmod a+x /etc/rc.local
