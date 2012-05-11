<?php
// $Id$
// Stat for VES-Media Module - Help Hook
// (C) 2007-2012 Alex Radetsky <rad@rad.kiev.ua> 
//

/**
* Display help and module information
* @param path which path of the site we're displaying help
* @param arg array that holds the current path as would be returned from arg() function
* @return help text for the path
*/
function vesmedia_help($path, $arg) {
        $output = '';  //declare your output variable
        switch ($path) {
                case "admin/help#vesmedia":
                        $output = '<p>'.  t("Данный модуль разработан специально под нужды контент-провайдера VES-media") .'</p>';
                        break;
        }
        return $output;
}


