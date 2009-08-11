jQuery.linkyq = {
  queue: [],
  cache: {},
  status: 'stopped',
  run: function() {
    if (this.queue.length == 0)
      return;

    if (this.status == 'stopped') {
      this.status = 'running';
      job = this.queue.shift();
      if (this.cache[job.url] != undefined) {
        //console.log('Returning cached data for: ' + job.url);
        job.callback(this.cache[job.url], job.context);
        this.status = 'stopped';
        this.run();
      }
      else {
        //console.log('Running job for: ' + job.url);
        $.getJSON(job.url, function(data) {
          jQuery.linkyq.cache[job.url] = data;
          job.callback(data, job.context);
          jQuery.linkyq.status = 'stopped';
          jQuery.linkyq.run();
        });
      }
    }
  },
  add: function(url, context, callback) {
    //console.log('Queuing job: ' + url);
    this.queue.push({url: url, callback: callback, context: context});
    this.run();
  }
};
