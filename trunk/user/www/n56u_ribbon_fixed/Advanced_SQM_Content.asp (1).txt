<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#menu5_14_1#></title>
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
    init_itoggle('sqm_enabled', change_sqm_enabled);
    change_sqm_enabled();
});

</script>

<script>
<% login_state_hook(); %>

function initial(){
    show_banner(1);
    show_menu(5,12,1);
    show_footer();
}

function applyRule(){
    if(validForm()){
        showLoading();
        
        document.form.action_mode.value = " Apply ";
        document.form.current_page.value = "/Advanced_SQM_Content.asp";
        document.form.next_page.value = "";
        
        document.form.submit();
    }
}

function done_validating(action){
    refreshpage();
}

function change_sqm_enabled(){
    var v = document.form.sqm_enabled[0].checked;
    showhide_div("sqm_download_speed", v);
    showhide_div("sqm_upload_speed", v);
    showhide_div("sqm_interface", v);
}

function validForm(){
    if (!document.form.sqm_enabled[0].checked) {
        return true;
    }

    var upload_speed = document.form.sqm_upload_speed.value;
    var download_speed = document.form.sqm_download_speed.value;
    var interface = document.form.sqm_interface.value;

    if (upload_speed == "" || download_speed == "" || interface == "") {
        alert("Please fill in all the fields.");
        return false;
    }

    if (!isNaN(upload_speed) || !isNaN(download_speed)) {
        var ul = Number.parseFloat(upload_speed);
        var dl = Number.parseFloat(download_speed);
        if (!Number.isInteger(ul) || !Number.isInteger(dl)) {
            alert("Please enter a valid value.");
            return false;
        }
    }
    else 
    {
        alert("Please enter a valid value.");
        return false;
    }

    if (upload_speed < 0 || download_speed < 0) {
        alert("Please enter a valid integer for upload and download speed.");
        return false;
    }

    return true;
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

    <input type="hidden" name="current_page" value="Advanced_SQM_Content.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="ExtraApplications;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">

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
                            <h2 class="box_head round_top"><#menu5_14_1#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <div class="alert alert-info" style="margin: 10px;"> <#SQM_Desc#></a>
                                    <span style="color:#FF0000;" class=""></span></div>

                                    <table width="100%" align="center" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th colspan="4" style="background-color: #E3E3E3;">Status</th>
                                        </tr>
                                        <tr id="sqm_enable_tr" > <th width="50%"><#SQM_Toggle#></th>
                                            <td>
                                                    <div class="main_itoggle">
                                                    <div id="sqm_enabled_on_of">
                                                        <input type="checkbox" id="sqm_enabled_fake" <% nvram_match_x("", "sqm_enabled", "1", "value=1 checked"); %><% nvram_match_x("", "sqm_enabled", "0", "value=0"); %> >
                                                    </div>
                                                </div>
                                                <div style="position: absolute; margin-left: -10000px;">
                                                    <input type="radio" value="1" name="sqm_enabled" id="sqm_enabled_1" onclick="change_sqm_enabled();" <% nvram_match_x("", "sqm_enabled", "1", "checked"); %>><#checkbox_Yes#>
                                                    <input type="radio" value="0" name="sqm_enabled" id="sqm_enabled_0" onclick="change_sqm_enabled();" <% nvram_match_x("", "sqm_enabled", "0", "checked"); %>><#checkbox_No#>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr id="sqm_interface"> <th width="50%"><#SQM_If#></th>
                                            <td>
                                                <input type="text" maxlength="64" class="input" size="64" name="sqm_interface" value="<% nvram_get_x("","sqm_interface"); %>" />
                                            </td>
                                        </tr>
                                        <tr id="sqm_download_speed"> <th width="50%"><#SQM_DL#></th>
                                            <td>
                                                <input type="text" maxlength="64" class="input" size="64" name="sqm_download_speed" value="<% nvram_get_x("","sqm_download_speed"); %>" />
                                            </td>
                                        </tr>
                                        <tr id="sqm_upload_speed"> <th width="50%"><#SQM_UL#></th>
                                            <td>
                                                <input type="text" maxlength="64" class="input" size="64" name="sqm_upload_speed" value="<% nvram_get_x("","sqm_upload_speed"); %>" />
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