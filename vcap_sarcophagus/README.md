# VCAP Sarcophagus

This directory is intended to confine code
relating to the "VCAP framework". 

## Objective

The sarcophagus will help separate code responsible for cloud controller "business logic"
from "framework" code that can be replaced with Rails. 
This will let us delete the code in the sarcophagus
once we are able to remove the v2 API (and move fully to Rails).

The distinction between "business logic" code and "framework" code is
fuzzy at best, so this will likely take multiple iterations to get
right. Hopefully this will help us better track calls that cross the
boundary between the sarcophagus and the rest of the codebase.

This is all working under the assumption that the VCAP framework
is a useful construct to think about.
It's possible that trying to separate the framework will reveal that 
there isn't value in thinking about the VCAP framework as a coherent entity.

## VCAP Framework

The VCAP Framework is not a true standalone framework,
but a set of extensions built on top of Sinatra
in conjunction with the early development of Cloud Controller.
It is sometimes easier to think about by comparing it
with other elements of CC.
1. It is often code that can be replaced by Rails.
2. It is often NOT code that implements logic that is specific to CC.
3. It may, however, impact the structure or interaction methods of the v2 API.
4. It is likely not used or is used less by the v3 API than the v2 API.

## Removal Plan

Some portions of the VCAP framework will be removed
along with the removal of the v2 API.
This will likely be portions that back the v2 controller layer.

Other portions of the VCAP framework that impact the operation of the v3 API
will need to be removed at a later date or formally re-integrated
into the rest of the Cloud Controller.
This will likely be portions the back the shared v2/v3 model layer.
