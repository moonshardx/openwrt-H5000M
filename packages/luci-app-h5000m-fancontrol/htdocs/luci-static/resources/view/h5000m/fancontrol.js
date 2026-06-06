'use strict';
'require view';
'require form';
'require fs';
'require ui';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('h5000m_fancontrol', _('H5000M 风扇控制'));
		m.description = _('调节 PWM 风扇策略。');

		s = m.section(form.NamedSection, 'settings', 'settings');
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('启用'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.ListValue, 'mode', _('模式'));
		o.value('auto', _('自动'));
		o.value('manual', _('手动'));
		o.value('off', _('关闭'));
		o.default = 'auto';
		o.rmempty = false;

		o = s.option(form.Value, 'manual_pwm', _('手动 PWM'));
		o.datatype = 'range(0,255)';
		o.default = '160';

		o = s.option(form.Value, 'min_pwm', _('最低 PWM'));
		o.datatype = 'range(0,255)';
		o.default = '80';

		o = s.option(form.Value, 'max_pwm', _('最高 PWM'));
		o.datatype = 'range(0,255)';
		o.default = '255';

		o = s.option(form.Value, 'low_temp', _('低温阈值'));
		o.datatype = 'range(0,120)';
		o.default = '45';

		o = s.option(form.Value, 'high_temp', _('高温阈值'));
		o.datatype = 'range(1,120)';
		o.default = '70';

		o = s.option(form.Value, 'interval', _('刷新间隔'));
		o.datatype = 'range(5,300)';
		o.default = '15';

		m.handleSaveApply = function(ev, mode) {
			return form.Map.prototype.handleSaveApply.apply(this, [ ev, mode ]).then(function() {
				return fs.exec('/usr/sbin/h5000m-fancontrol', [ 'apply' ]).then(function() {
					return fs.exec('/etc/init.d/h5000m-fancontrol', [ 'restart' ]);
				}).then(function() {
					ui.addNotification(null, E('p', _('风扇控制已应用。')));
				}, function(err) {
					ui.addNotification(null, E('p', _('风扇控制应用失败：') + err.message), 'danger');
				});
			});
		};

		return m.render();
	}
});
