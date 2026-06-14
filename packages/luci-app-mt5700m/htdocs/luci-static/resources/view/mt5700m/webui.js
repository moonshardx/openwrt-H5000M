'use strict';
'require view';

return view.extend({
	render: function() {
		var url = window.location.protocol + '//' + window.location.host + '/5700/';

		return E('div', {}, [
			E('style', {}, [
				'.mt5700m-webui-frame{width:100%;height:calc(100vh - 190px);min-height:720px;border:1px solid var(--border-color-medium,#d8d8d8);border-radius:6px;background:#fff}',
				'.mt5700m-webui-actions{display:flex;gap:8px;align-items:center;margin:0 0 12px}'
			].join('')),
			E('h2', {}, _('MT5700M Native WebUI')),
			E('div', { 'class': 'mt5700m-webui-actions' }, [
				E('a', {
					'class': 'btn cbi-button',
					'href': url,
					'target': '_blank',
					'rel': 'noopener noreferrer'
				}, _('Open in new tab'))
			]),
			E('iframe', {
				'class': 'mt5700m-webui-frame',
				'src': url,
				'title': 'MT5700M WebUI'
			})
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
