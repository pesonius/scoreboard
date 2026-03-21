const express = require('express');
const path = require('path');
const app = express();

app.use(express.static(__dirname));

app.listen(3000, '0.0.0.0', () => {
  console.log('Scoreboard at http://0.0.0.0:3000');
  console.log('On iPad, use your Mac\'s local IP address, e.g. http://192.168.x.x:3000');
});
