<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#menu5_13_1#></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/itoggle.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script>
var $j = jQuery.noConflict();

$j(document).ready(function() {
    init_itoggle('agh_enable', change_agh_enable);
    change_agh_enable();
});

</script>
<script>

<% login_state_hook(); %>

function initial(){
    show_banner(1);
    show_menu(7, 7, 9); // Sửa thành (7, 7, 9) để sáng đúng Tab 9
    show_footer();
    if (!login_safe())
        textarea_scripts_enabled(0);
}

function applyRule(){
    if(validForm()){
        showLoading();
        
        document.form.action_mode.value = " Apply ";
        document.form.current_page.value = "/Advanced_AdGuardHome_Content.asp";
        document.form.next_page.value = "";
        
        document.form.submit();
    }
}

function validForm(){
    var v = document.form.agh_port.value
    if (v < 1024 || v > 65535) {
        alert("<#AdGuard_InvalidPort#>");
        return false;
    }
    return true;
}

function change_agh_enable(){
    var v = document.form.agh_enable[0].checked;
    showhide_div("agh_port_tr", v);
}

function done_validating(action){
    refreshpage();
}

function button_AdGuardHome_wan_port(){
		var port =  document.form.agh_port.value;
		var porturl ='http://' + window.location.hostname + ":" + port;
		window.open(porturl,'AdGuardHome_wan_port');
}

</script>
</head>

<body onload="initial();" onunLoad="return unload_body();">

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9" >
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">

    <input type="hidden" name="current_page" value="Advanced_AdGuardHome_Content.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="ExtraApplications;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="restart_firewall">

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <!--Sidebar content-->
                <!--=====Beginning of Main Menu=====-->
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li>
                            <div id="subMenu" class="accordion"></div>
                        </li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <!--Body content-->
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_13_1#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <div class="alert alert-info" style="margin: 10px;"> <#AdGuardHome_Desc#> <a href="https://adguard.com/en/adguard-home/overview.html" target="blank">AdGuard Home</a>
                                    <span style="color:#FF0000;" class=""></span></div>

                                    <table width="100%" align="center" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th colspan="4" style="background-color: #E3E3E3;">Status</th>
                                        </tr>
                                        <tr id="AdGuardHome_enable_tr" >
                                            <th width="50%"><#AdGuardHome_Toggle#></th>
                                            <td>
                                                <div class="main_itoggle">
                                                    <div id="agh_enable_on_of">
                                                        <input type="checkbox" id="agh_enable_fake" <% nvram_match_x("", "agh_enable", "1", "value=1 checked"); %><% nvram_match_x("", "agh_enable", "0", "value=0"); %> >
                                                    </div>
                                                </div>
                                                <div style="position: absolute; margin-left: -10000px;">
                                                    <input type="radio" value="1" name="agh_enable" id="agh_enable_1" <% nvram_match_x("", "agh_enable", "1", "checked"); %>><#checkbox_Yes#>
                                                    <input type="radio" value="0" name="agh_enable" id="agh_enable_0" <% nvram_match_x("", "agh_enable", "0", "checked"); %>><#checkbox_No#>
                                                </div>
                                            </td>
                                            <td colspan="2" style="border-top: 0 none;">
												<input class="btn btn-success" style="" type="button" value="<#AdGuardHome_WebIf#>" onclick="button_AdGuardHome_wan_port()" tabindex="24">
											</td>
                                        </tr>
                                        <tr id="agh_port_tr"> <th><#AdGuardHome_Port#></th>
                                            <td>
                                                <input type="text" maxlength="64" class="input" size="64" name="agh_port" value="<% nvram_get_x("","agh_port"); %>" />
                                            </td>
                                        </tr>
                                        <tr>
                                            <td colspan="4" style="border-top: 0 none;">
                                                <br />
                                                <center><input class="btn btn-primary" style="width: 219px" type="button" value="<#CTL_apply#>" onclick="applyRule()" /></center>
                                            </td>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    </form>
    <div id="footer"></div>
</div>
</body>
</html>
