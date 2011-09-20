function getData(resource, data, callback, errorCallback) {
	if (errorCallback === undefined)
		errorCallback = alert;

	$.ajax({
		url : '/data/' + resource,
		data : data,
		dataType : 'json',
		success : function(data) {
			if (data.error)
				errorCallback(data.error);
			else
				callback(data);
		},
		error : function(jqXHR, textStatus, errorThrown) {
			errorCallback(textStatus + ' - ' + errorThrown);
		}
	});
}

var baseUrl;

$(function() {
	$('#main-title').text('Loading...');

	getData('dates', null, function(dates) {
		$('#main-title').text('ForumAntiSpam');
		$('#inner').animate({width: 900});
		var html = '';
		for (var i in dates)
			html += '<div class="panel datepanel"><h1>' + dates[i] + '</h1></div>';
		var div = $('<div>').hide().html(html);
		$('#inner').append(div);
		div.slideDown();

		$('.datepanel h1').css('cursor', 'pointer').mousedown(function() {
			var date = $(this).text();
			var content = $('#content-'+date);
			if (content.length==0)
			{
				var header = $(this);
				header.text('Loading...')
				getData('posts', {'date':date}, function(posts) {
					header.text(date);

					var div = $('<div id="content-'+date+'">');
					for (var i in posts)
						(function() {
							var post = posts[i];
							var content = $('<div class="content"><table>'+
								'<tr><td>Post</td><td class="post-id"></td></tr>'+
								'<tr><td>Time</td><td class="post-time"></td></tr>'+
								'<tr><td>User</td><td class="post-user"></td></tr>'+
								'<tr><td>IP</td><td class="post-ip"></td></tr>'+
								'<tr><td>Subject</td><td class="post-title"></td></tr>'+
								'<tr><td>Text</td><td class="post-text"></td></tr>'+
								'<tr><td>Results</td><td class="post-results">Loading...</td></tr>'+
								'<tr><td>Verdict</td><td class="post-verdict"></td></tr>'+
								'</table></div>');
							content.hide();
							content.find('td:first-child').css('width', '100px');
							content.find('.post-id').html('<a href="'+baseUrl+'showpost.php?p='+post.id+'">'+post.id+'</a>');
							content.find('.post-time').text(post.time);
							var userHtml = escapeHtml(post.user);
							content.find('.post-user').html('<a href="'+baseUrl+(post.userid ? 'member.php?u='+post.userid : 'memberlist.php?ausername='+userHtml)+'">'+userHtml+'</a>');
							content.find('.post-ip').text(post.ip);
							content.find('.post-title').text(post.title);
							content.find('.post-text').text(post.text);
							if (post.moderated)
								content.find('.post-verdict').text(post.verdict ? 'SPAM, deleted' : 'not spam').addClass(post.verdict ? 'spam' : 'ham');
							else
								content.find('.post-verdict').text('Not checked');

							var getResults = function(animate) {
								getData('results', {'id':post.id}, function(results) {
									if (results.length==0) {
										content.find('.post-results').text('Not checked');
										return;
									}
									var table = $('<div><table><tr>'+
										'<th style="width: 150px">Engine</th>'+
										'<th style="width: 100px">Time</th>'+
										'<th style="width:  45px">Result</th>'+
										'<th>Details</th>'+
										'<th colspan="2">Feedback</th>'+
										'</tr></table>');
									for (var i in results)
										(function() {
											var result = results[i];
											var row = $('<tr>'+
												'<td>'+result.name+'</td>'+
												'<td>'+result.time+'</td>'+
												'<td class="'+(result.result ? 'spam' : 'ham')+'">'+(result.result ? 'SPAM' : 'not spam')+'</td>'+
												'<td>'+escapeHtml(result.details)+'</td>'+
												(result.feedbackSent ?
													'<td colspan="2">Feedback sent on ' + result.feedbackTime + ' as <span class="'+(result.feedbackVerdict ? 'spam' : 'ham')+'">'+(result.feedbackVerdict ? 'SPAM' : 'not spam')+'</td>'
												:
													'<td class="feedback">'+(result.canSendSpam ? '<button class="spam">SPAM</button>' : '')+'</td>'+
													'<td class="feedback">'+(result.canSendHam  ? '<button class="ham">HAM</button>'   : '')+'</td>'
												)+
												'</tr>');
											var sendFeedback = function(isSpam) {
												var progress = $('<td colspan="2">').text('Sending...');
												row.find('.feedback').first().before(progress);
												row.find('.feedback').remove();
												getData('feedback', {'name':result.name, 'id':post.id, 'spam':isSpam}, function() {
													progress.text('Refreshing...');
													getResults(false);
												})
											}
											row.find('button.spam').click(function() { sendFeedback(true ); });
											row.find('button.ham' ).click(function() { sendFeedback(false); });
											table.find('table').append(row);
										})();
									if (animate) table.hide();
									content.find('.post-results').empty().append(table).css('padding', '4px');
									if (animate) table.slideDown();
								});
							}

							var postDiv = $('<div class="panel postpanel"><h1></h1></div>');
							var resultsLoaded = false;
							postDiv.append(content);
							postDiv.find('h1')
								.text(post.time.substr(12, 8)+' — '+post.user+' — '+post.title.substr(0, 60))
								.prepend(post.moderated ? $('<div title="Verdict" class="'+(post.verdict?'spam':'ham')+'" style="float:right">'+(post.verdict ? 'SPAM' : 'not spam')+'</div>') : '')
								.css('text-align', 'left')
								.css('cursor', 'pointer')
								.mousedown(function() {
									content.slideToggle('fast', function() {
										if (!resultsLoaded) {
											resultsLoaded = true;
											getResults(true);
										}
									});
								});
							div.append(postDiv);
						})();
					div.hide();

					header.after(div);
					div.slideDown()
				});
			}
			else
				content.slideToggle();
		});
	});

	getData('info', null, function(info) {
		baseUrl = info.baseUrl;
	});
});

function escapeHtml(text)
{
	return $('<div>').text(text).html();
}
